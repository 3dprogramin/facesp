<template>
    <div class="webcam-container">
        <div class="canvas-container">
            <!-- Colored image -->
            <canvas ref="canvasWebcamRef" width="128" height="64"></canvas>

            <!-- B/W image, as sent through MQTT -->
            <canvas class="canvas-bw" ref="canvasBWRef" width="128" height="64"></canvas>
        </div>

        <!-- Show webcam stream in real-time -->
        <div class="video-container">
            <video ref="videoRef" autoplay playsinline></video>
            <!-- Shows when websocket is connected -->
            <div v-if="mqttConnected && videoStream" title="Streaming" class="connection-dot"></div>
        </div>
        <!-- End webcam stream -->

        <!-- Start / stop webcam stream -->
        <button :disabled="videoStream !== null" @click="start">Start</button>
        <button :disabled="videoStream === null" @click="stop">Stop</button>
        <!-- End start / stop -->

        <!-- Settings -->
        MQTT WS server URL: <input type="text" :disabled="mqttConnected" v-model="MQTTWebSocketURL" />
        MQTT user: <input type="text" :disabled="mqttConnected" v-model="MQTTUser" />
        MQTT password: <input type="text" :disabled="mqttConnected" v-model="MQTTPassword" id="mqtt-password" />
        Threshold: <input type="number" v-model="threshold" />
        Snapshot time (ms): <input type="number" v-model="snapshotTime" @blur="resetSnapshotInterval" />
        <!-- End settings -->

        <!-- Error paragraph in case of error -->
        <p v-if="error">{{ error }}</p>
    </div>
</template>

<script setup>
import { ref, onUnmounted, computed } from 'vue';
import mqtt from 'mqtt';

// user defined inputs
const snapshotTime = ref(1000);
const threshold = ref(128);

const MQTTWebSocketURL = ref("ws://127.0.0.1:4041");
const MQTTUser = ref("facesp");
const MQTTPassword = ref("facesp_MQTT_passwd_should_be_replaced!");
const canvasBWRef = ref(null);
const canvasWebcamRef = ref(null);
const videoRef = ref(null);
const videoStream = ref(null);
const error = ref('');
const mqttConnected = ref(false);
const stopped = ref(false);
let mqttClient = null;
let snapshotInterval = null;

const computedThreshold = computed({
    get() {
        let t = parseInt(threshold.value);
        if (isNaN(t)) return 0;
        return t;
    }
})

const computedSnapshotTime = computed({
    get() {
        let t = parseInt(snapshotTime.value);
        if (isNaN(t)) return 100;
        return t;
    }
})

// reset the snapshot interval
// although this can be made to snapshot quicker it depends on the IoT device as well
// if it's too quick, the IoT device will receive each frame but delayed
const resetSnapshotInterval = () => {
    if (snapshotInterval) clearInterval(snapshotInterval);
    snapshotInterval = setInterval(snapshot, computedSnapshotTime.value)
};

// start webcam streaming
// first time user will be asked to allow the webcam
// also connect to MQTT server
const start = async () => {
    error.value = '';
    stopped.value = false;
    try {
        const stream = await navigator.mediaDevices.getUserMedia({ video: true });
        videoRef.value.srcObject = stream;
        videoStream.value = stream;
        error.value = ''; // Reset error message if successful
        resetSnapshotInterval();
    } catch (err) {
        console.error("Error accessing the webcam:", err);
        error.value = `Error accessing the webcam: ${err.message}`;
    }

    // connect to MQTT server through websocket
    try {
        mqttClient = mqtt.connect(MQTTWebSocketURL.value, {
            username: MQTTUser.value,
            password: MQTTPassword.value
        });
        mqttClient.on('connect', () => {
            console.log('Connected to MQTT broker')
            mqttConnected.value = true;
        })
        mqttClient.on('close', () => {
            console.log('Disconnected from MQTT broker');
            if (!stopped.value) {
                error.value = "Disconnected or can't connect to MQTT broker";
            }
            mqttConnected.value = false; // Set connection status to false
        })
        mqttClient.on('error', (err) => {
            console.error("Cannot connect to MQTT server:", err);
            error.value = `Cannot connect to MQTT server: ${err.message}`;
            mqttConnected.value = false;;
        })
    } catch (err) {
        console.error("Cannot connect to MQTT server:", err);
        error.value = `Cannot connect to MQTT server: ${err.message}`;
    }
};

// stop webcam, stop stream
const stop = () => {
    stopped.value = true;
    if (videoStream.value) {
        videoStream.value.getTracks().forEach(track => track.stop());
        videoStream.value = null;
    }
    // clear the snapshot interval
    if (snapshotInterval) clearInterval(snapshotInterval);

    if (mqttClient && mqttClient.connected) {
        mqttClient.end(() => {
            console.log('Disconnected from MQTT broker');
        });
    }
};

// takes snapshots of the webcam every couple of milliseconds
const snapshot = () => {
    const context = canvasWebcamRef.value.getContext('2d');
    context.drawImage(videoRef.value, 0, 0, canvasWebcamRef.value.width, canvasWebcamRef.value.height);
    // const dataUrl = canvasWebcamRef.value.toDataURL('image/png');

    // convert to black and white
    const context2 = canvasBWRef.value.getContext('2d');
    blackAndWhite(context, context2)

    // generate output string
    const output = generateOutput(canvasBWRef.value);

    // send output through MQTT
    if (mqttConnected.value) {
        mqttClient.publish('facesp', output)
    }
};

// convert colored image to black and white
const blackAndWhite = (context, context2) => {
    var imageData = context.getImageData(0, 0, 128, 64);
    var data = imageData.data;
    for (var i = 0; i < data.length; i += 4) {
        var avg = (data[i] + data[i + 1] + data[i + 2]) / 3;
        avg > computedThreshold.value ? avg = 255 : avg = 0;
        data[i] = avg; // red
        data[i + 1] = avg; // green
        data[i + 2] = avg; // blue
    }
    context2.putImageData(imageData, 0, 0);
};

// generate output that will be sent to mqtt broker
const generateOutput = (canvas) => {
    const ctx = canvas.getContext("2d");

    var imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
    var data = imageData.data;

    const oneBit = imageToBytes(data, canvas.width).replace(/,\s*$/g, "");
    const converted = convertToDecimal(oneBit);
    return converted;
};

// convert hex to dec
const convertToDecimal = (output) => {
    let converted = ''
    let counter = 0
    output.split(',').forEach(e => {
        e = e.trim()
        e = parseInt(e, 16)
        // if (e > 0) e = 1;
        converted += e + ' '
        counter += 1
    })
    return `${counter}|${converted.trim()}\n`
}

// credits - https://javl.github.io/image2cpp/
const imageToBytes = (data) => {
    const canvasWidth = 128;
    var output_string = "";
    var output_index = 0;

    var byteIndex = 7;
    var number = 0;

    // format is RGBA, so move 4 steps per pixel
    for (var index = 0; index < data.length; index += 4) {
        // Get the average of the RGB (we ignore A)
        var avg = (data[index] + data[index + 1] + data[index + 2]) / 3;
        if (avg > computedThreshold.value) {
            number += Math.pow(2, byteIndex);
        }
        byteIndex--;

        // if this was the last pixel of a row or the last pixel of the
        // image, fill up the rest of our byte with zeros so it always contains 8 bits
        if ((index != 0 && (((index / 4) + 1) % (canvasWidth)) == 0) || (index == data.length - 4)) {
            // for(var i=byteIndex;i>-1;i--){
            // number += Math.pow(2, i);
            // }
            byteIndex = -1;
        }

        // When we have the complete 8 bits, combine them into a hex value
        if (byteIndex < 0) {
            var byteSet = number.toString(16);
            if (byteSet.length == 1) {
                byteSet = "0" + byteSet;
            }
            var b = "0x" + byteSet;
            output_string += b + ", ";
            output_index++;
            if (output_index >= 16) {
                output_string += "\n";
                output_index = 0;
            }
            number = 0;
            byteIndex = 7;
        }
    }
    return output_string;
}

onUnmounted(() => {
    stop();
});
</script>

<style scoped>
.webcam-container {
    display: flex;
    flex-direction: column;
    align-items: center;
}

.canvas-container {
    margin-bottom: 20px;
}

.canvas-bw {
    margin-left: 50px;
}

video {
    width: 100%;
    max-width: 600px;
    margin-bottom: 10px;
}

button {
    margin: 5px;
}

p {
    color: red;
    margin-top: 10px;
}

.video-container {
    position: relative;
    display: inline-block;
}

.connection-dot {
    position: absolute;
    top: 15px;
    /* Adjust these values to your desired position */
    left: 15px;
    /* Adjust these values to your desired position */
    width: 20px;
    /* Adjust the size of the dot */
    height: 20px;
    /* Adjust the size of the dot */
    background-color: rgb(255, 0, 0);
    border-radius: 50%;
}

button {
    width: 100px;
}

button:last-of-type {
    margin-bottom: 20px;
}

#mqtt-password {
    margin-bottom: 20px;
}
</style>