/* 
subflow - a music visualizer
Copyright (C) 2021-2023 Ello Skelling Productions

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#ifndef constants_h
#define constants_h

#define PULSE_TS_NUDGE 0.05l
#define SCALE_MIN 0.7f
#define SCALE_MAX 1.3f
#define DEFAULT_PULSE_SCALE 1.13f
#define PULSE_K 0.1f
#define SPEED_MIN 0.3f
#define SPEED_MAX 6.3f
#define SPEED_STEP 0.5f
#define DEFAULT_SPEED 1.0f
#define FAR_Z_LIMIT 15.0f
#define NEAR_Z_LIMIT 0.1f
#define SECS_PER_MOVE 16.0f
#define TRI_SPACE 0.5l
#define NUM_TRIANGLES 60
#define WARP_LP_K 0.3f
#define SPEED_LP_K 0.1f
#define SWITCH_K_LP_K 0.3f
#define INIT_SWITCH_K 0.4f
#define FADE_K_K 0.3f
#define Y_OFFSET_LOW 0.4f

#define MODE_OFF 0u
#define MODE_STP 1u
#define MODE_LIN 2u
#define MODE_FUL 3u
#define MODE_SRC 4u
#define MODE_SPR 5u
#define MODE_SHM 6u
#define MODE_PMP 7u
#define FIRST_MODE MODE_OFF
#define LAST_MODE MODE_PMP
#define DELAYS_SIZE 5

#define CMD_COLOR_MIN 0u
#define CMD_COLOR_MAX 63u

#define DEBOUNCE_COLORSWITCH_T 2.0l
#define RGB_COLOR_RED 48u
#define RGB_COLOR_WHT 63u

#define CMD_BPM_MAX 480.0f
#define CMD_BPM_MIN 20.0f

#define UDP_PORT 37020
#define TCP_PORT 37023
#define UDP_MAGIC "24379"
#define UDP_BPM "BPM"
#define UDP_LOOP "LOP"
#define UDP_MODE "MOD"
#define UDP_SPEED "SPD"
#define UDP_SCALE "SCL"
#define UDP_COL "COL"
#define UDP_NONE "NON"
#define MAX_INST_CMD_SEQ 10
#define MAX_LOOPS 2000000000

#endif /* constants_h */
