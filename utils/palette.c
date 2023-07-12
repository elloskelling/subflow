#include <stdio.h>
#include <math.h>
#include <stdlib.h>

void char2RGB(unsigned char color, float *rgb) {
    unsigned char red = (color >> 4) & 0x03;
    unsigned char green = (color >> 2) & 0x03;
    unsigned char blue = color & 0x03;

    rgb[0] = ((float)red)/3.;
    rgb[1] = ((float)green)/3.;
    rgb[2] = ((float)blue)/3.;
}

unsigned char RGB2char(float redf, float greenf, float bluef) {
	unsigned char red = (int)roundf(redf*3.);
	unsigned char green = (int)roundf(greenf*3.);
	unsigned char blue = (int)roundf(bluef*3.);
    unsigned char color = (red << 4) | (green << 2) | blue;
    return color;
}

int main(int argc, char *argv[]) {

    if (argc == 2){
	    float rgb[3] = {0};
	    unsigned char color = (unsigned char)(atoi(argv[1]));
    	char2RGB(color, rgb);
    	printf("> ColorCode: %d\n", color);
	    printf("<      Red: %f\n", rgb[0]);
	    printf("<    Green: %f\n", rgb[1]);
	    printf("<     Blue: %f\n", rgb[2]);
    }


    if (argc == 4){
	    float rgb[3] = {atof(argv[1]),atof(argv[2]),atof(argv[3])};
	    unsigned char color = RGB2char(rgb[0],rgb[1],rgb[2]);
    	char2RGB(color, rgb);
	    printf(">      Red: %f\n", rgb[0]);
	    printf(">    Green: %f\n", rgb[1]);
	    printf(">     Blue: %f\n", rgb[2]);
    	printf("< ColorCode: %d\n", color);
    }
    return 0;
}