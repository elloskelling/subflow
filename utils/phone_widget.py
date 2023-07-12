### subflow - a music visualizer
### Copyright (C) 2021-2023 Ello Skelling Productions

### This program is free software: you can redistribute it and/or modify
### it under the terms of the GNU Affero General Public License as published
### by the Free Software Foundation, either version 3 of the License, or
### (at your option) any later version.

### This program is distributed in the hope that it will be useful,
### but WITHOUT ANY WARRANTY; without even the implied warranty of
### MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
### GNU Affero General Public License for more details.

### You should have received a copy of the GNU Affero General Public License
### along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Intended to be used with Pythonista (https://www.omz-software.com/pythonista/)
# This will build an iOS widget that allows you to command any subflow instance on the same network

import appex, ui
import console
import os
import sys
import socket

class SubflowView (ui.View):
    def __init__(self, *args, **kwargs):
        super().__init__(self, *args, **kwargs)
        self.shows_result = False
        self.bounds = (0, 0, 400, 200)
        button_style = {'background_color': (0, 0, 0, 0.05), 'tint_color': 'black', 'font': ('HelveticaNeue-Light', 17), 'corner_radius': 3}
        self.send_button = ui.Button(title='Send', action=self.button_tapped, **button_style)
        self.add_subview(self.send_button)
        self.display_view = ui.View(background_color=(.54, .94, 1.0, 0.2))
        self.bpm_field = ui.TextField(frame=self.display_view.bounds.inset(0, 0), flex='wh', text='120', alignment=ui.ALIGN_LEFT)
        self.bpm_field.font = ('HelveticaNeue-Light', 17)
        self.display_view.add_subview(self.bpm_field)
        self.add_subview(self.display_view)
    
    def layout(self):
        bw = self.width / 10
        bh = self.height / 4
        self.send_button.frame = ui.Rect(4 * bw, 0 * bh, 2*bw, 1 * bh).inset(0, 0)
        self.display_view.frame = (0, 0, 4*bw, bh)
        
    def button_tapped(self,sender):
        '@type sender: ui.Button'
        # Get the button's title for the following logic:
        t = sender.title
        if t == 'Send':
            self.send_bpm(self.bpm_field.text)
    
    def send_bpm(self,bpmstr):
        port  = 37020
        magic = "subflow24379"
        cmd   = "BPM"
        bpm   = bpmstr
    
        try:
            fbpm = float(bpm)
            if fbpm < 20 or fbpm > 250:
                sys.exit("Please make 20 <= bpm <= 250")
        except ValueError:
            sys.exit("bpm argument must be a float")
    
        sendstr = ":".join([magic,cmd,bpm])
    
        server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        server.settimeout(1.0)
        server.sendto(sendstr.encode('utf-8'), ('<broadcast>', port))
    
def main():
    # Optimization: Don't create a new view if the widget already shows the calculator.
    widget_name = __file__ + str(os.stat(__file__).st_mtime)
    widget_view = appex.get_widget_view()
    if widget_view is None or widget_view.name != widget_name:
        widget_view = SubflowView()
        widget_view.name = widget_name
        appex.set_widget_view(widget_view)

if __name__ == '__main__':
    main()
