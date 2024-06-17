// -----------------
// facesp
// -----------------
// main variables
LENGTH = 58;
WIDTH = 32;
HEIGHT = 15;          // bottom height
HEIGHT_MAIN = 30;     // top height
MINKOWSKI_RADIUS = 2; // contains wall size too
$fn = 100;

// misc
BINDING_HEIGHT = 6;
ESP_HOLDER_WIDTH = 2.5;
ESP_HOLDER_HEIGHT = 9;
IN_OUT_DIFF = 1; // add extra size in walls

// BOTTOM
// --------
module baseBottom() {
    difference() {
        // main base
        minkowski() {
            cube([LENGTH + IN_OUT_DIFF, WIDTH + IN_OUT_DIFF, HEIGHT], center=true);
            sphere(MINKOWSKI_RADIUS);
        }
        // cut top off
        translate ([0, 0, HEIGHT/2]) {
            cube([LENGTH * 2, WIDTH * 2, HEIGHT], center=true);
        }
        // cut main base
        minkowski() {
            cube([LENGTH - MINKOWSKI_RADIUS * 2, WIDTH - MINKOWSKI_RADIUS * 2, HEIGHT-MINKOWSKI_RADIUS], center=true);
            sphere(MINKOWSKI_RADIUS);
        }
        // cut binding part
        translate([0, 0, 2]) difference() {
            translate([0, 0, -BINDING_HEIGHT]) linear_extrude(BINDING_HEIGHT) minkowski() {
                square([LENGTH + MINKOWSKI_RADIUS, WIDTH + MINKOWSKI_RADIUS], center=true);
                circle(MINKOWSKI_RADIUS);
            }
            translate([0, 0, -BINDING_HEIGHT]) linear_extrude(BINDING_HEIGHT) minkowski() {
                square([LENGTH - MINKOWSKI_RADIUS, WIDTH - MINKOWSKI_RADIUS], center=true);
                circle(MINKOWSKI_RADIUS);
            }
        }
    }
}

module esp_holder(){
    cylinder(ESP_HOLDER_HEIGHT, ESP_HOLDER_WIDTH / 2, ESP_HOLDER_WIDTH / 2, center=true);
}

module bulk_esp_holders() {
    h = -HEIGHT / 2 + MINKOWSKI_RADIUS * 2;
    translate([-22,-10.5,h]) esp_holder();
    translate([22,-10.5,h]) esp_holder();
    translate([-22,10.5,h]) esp_holder();
    translate([22,10.5,h]) esp_holder();
}

module usb_port() {
    points = [[-4.25,-1.25], [-3.5,1.25], [3.5,1.25], [4.25,-1.25]];
    translate([-1 * (LENGTH / 2) - MINKOWSKI_RADIUS * 2 - IN_OUT_DIFF * 2, 0, -1 * (HEIGHT / 2) + 1.5] ) scale([10, 1, 1]) rotate([90, 0, 90]) linear_extrude(1) polygon(points);
}

module logo() {
    translate([2, -3, -.5]) scale([1.5, 1.5, 1]) translate([- (HEIGHT / 2) - MINKOWSKI_RADIUS * 4, -7, -HEIGHT / 2 - MINKOWSKI_RADIUS + 4 / 2 - 1]) rotate([0, 180, -90]) linear_extrude(1.2) text("power", size=5);
}

module title() {
    translate([10, -1, 1]) scale([1.5, 1.5, 1]) translate([- (HEIGHT / 2) - MINKOWSKI_RADIUS * 4, -11, -HEIGHT / 2 - MINKOWSKI_RADIUS + 4 / 2 - 2]) rotate([-90, 180, 180]) linear_extrude(1.2) text("facesp", size=3.8);
}

module company() {
    translate([49, 28, 1]) scale([1.5, 1.5, 1]) translate([- (HEIGHT / 2) - MINKOWSKI_RADIUS * 4, -7, -HEIGHT / 2 - MINKOWSKI_RADIUS + 4 / 2 - 2]) rotate([90, 0 , 180]) linear_extrude(1.2) text("3dprogramin.io", size=3.8);
}

module on_off() {
    depth = -7; // on Z axis, for text
    translate([15, 0, depth]) scale([1.5, 1.5, 1]) translate([- (HEIGHT / 2) - MINKOWSKI_RADIUS * 4, -7, -HEIGHT / 2 - MINKOWSKI_RADIUS + 4 / 2 - 2]) rotate([180, 0 , 90]) linear_extrude(1.2) text("on", size=3);
    
        translate([1, 14, depth]) scale([1.5, 1.5, 1]) translate([- (HEIGHT / 2) - MINKOWSKI_RADIUS * 4, -7, -HEIGHT / 2 - MINKOWSKI_RADIUS + 4 / 2 - 2]) rotate([180, 0 , 90]) linear_extrude(1.2) text("off", size=3);
}

module bottom () {
    difference () {
        union () {
            difference () {
                baseBottom();
                usb_port();
            }
            //translate([-.25, 0, -1]) bulk_esp_holders(); // move one unit against usb port
        }
        logo();
        // usb cord
        translate([-31.5, 0, -5]) cube([2,12,7], center=true);
    }
}


// TOP
// -----
module top() {
    difference() {
        // main base
        minkowski() {
            cube([LENGTH + IN_OUT_DIFF, WIDTH + IN_OUT_DIFF, HEIGHT_MAIN], center=true);
            sphere(MINKOWSKI_RADIUS);
        }
        // cut top off
        translate ([0, 0, HEIGHT_MAIN/2]) {
            cube([LENGTH * 2, WIDTH * 2, HEIGHT_MAIN], center=true);
        }
        // cut main esp-exchangebase
        minkowski() {
            cube([LENGTH - MINKOWSKI_RADIUS * 2, WIDTH - MINKOWSKI_RADIUS * 2, HEIGHT_MAIN-MINKOWSKI_RADIUS], center=true);
            sphere(MINKOWSKI_RADIUS);
        }
        
        // cut for binding with top part
        // REQUIRES CHANGES !
        translate([0, 0, - BINDING_HEIGHT + 2]) linear_extrude(BINDING_HEIGHT) minkowski() {
            square([LENGTH-IN_OUT_DIFF - 0.75, WIDTH-IN_OUT_DIFF - 0.75], center=true);
            circle(MINKOWSKI_RADIUS);
        }
        // OLED display
        translate([WIDTH - 20 + MINKOWSKI_RADIUS, 0, -10]) cube([17.25,25.5,100],center=true);
        
        // title
        title();
        company();
        
        // usb cord
    translate([(-LENGTH / 2) - MINKOWSKI_RADIUS, 0, 2]) cube([6,12,7],  center=true); 
        
    // initially there was a button and on / off info
    // but took it out for now
    //translate([-18, -2, -1 * (HEIGHT_MAIN / 2) - MINKOWSKI_RADIUS * 2]) linear_extrude(30) square([9, 4]);
        // labels for switch
        //on_off();
    }
}

translate([0, 0, 15]) rotate([180,0,0]) bottom();
top();