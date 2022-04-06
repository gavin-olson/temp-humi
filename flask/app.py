from flask import Flask
from flask import request
from flask import render_template
from flask import send_file

import pygal

from datetime import date
from datetime import datetime
from datetime import timedelta

from collections import Counter

app = Flask(__name__)

@app.route('/')
def index():
    # Configuration constants
    hosts = {
        '192.168.135.190':{ 'name':'Garage',      'color':'red' },
        '192.168.135.191':{ 'name':'Basement',    'color':'blue' },
        '192.168.135.192':{ 'name':'Bedroom',     'color':'green' },
        '192.168.135.193':{ 'name':'Living Room', 'color':'orange' },
        '192.168.135.194':{ 'name':'Office',      'color':'cyan' }}
    sensors = [
        {'key':'temp',  'title':'Temperature (F)', 'ylabels':range(20,100,5),         'index':2},
        {'key':'humi',  'title':'Humidity (RH%)',  'ylabels':range(0,100,10),         'index':4},
        {'key':'press', 'title':'Pressure (Pa)',   'ylabels':range(98000,105000,1000), 'index':8}]
    expected_gap =  60 # Expected seconds between samples
    resolution   = 200 # How many samples per host

    # Get CGI parameters. Default is 1 day view starting now
    offset = int(request.args.get('offset', 0))
    period = int(request.args.get('range', 86400))
    
    # Compute time-axis endpoints for graphs
    end_date = datetime.today() - timedelta(seconds=offset)
    if period >= 86400:
        end_date = end_date.replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(days=1)
    start_date = end_date - timedelta(seconds=period)
    
    # Initialize data structures
    data = {}
    last_sample = {
        host:{
            'timestamp':datetime.fromtimestamp(0), 
            'count':Counter({sensor['key']:0 for sensor in sensors}), 
            'accumulator':Counter({sensor['key']:0.0 for sensor in sensors})
            } for host in hosts.keys()}

    # Read loop
    this_date = start_date
    while this_date <= end_date:
        try:
            this_file = open("/var/log/temp-humi-%s.dat" % this_date.strftime('%Y-%m-%d'))
        except:
            pass
        else:
            with this_file:
                for line in this_file:
                    fields = line.split(',')

                    # Parse timestamp and host to determine if we need this sample
                    timestamp = datetime.fromtimestamp(int(fields[0]))
                    host = fields[1]
                    time_gap = (timestamp - last_sample[host]['timestamp']).total_seconds()
                    
                    # Check if sample is in plot range
                    if start_date < timestamp < end_date:
                        # Count this sample. Value will be accumulated for each sensor in the sensor loop.
                        #last_sample[host]['count'] += 1
                        
                        # For each sensor value field that isn't empty, accumulate
                        last_sample[host]['accumulator'] += Counter({sensor['key']:float(fields[sensor['index']]) for sensor in sensors if fields[sensor['index']]})
                        last_sample[host]['count'] += Counter({sensor['key']:1 for sensor in sensors if fields[sensor['index']]})

                        # Check if it's time to plot
                        if time_gap > period / resolution:
                            # Iterate over the sensors, and append to plot data where data is present
                            for sensor in sensors:
                                # Insert a blank sample if it's been more than 2 sample gaps since the last sample to break the line
                                if time_gap > 2 * max(period / resolution, expected_gap):
                                    data.setdefault(sensor['key'],{}).setdefault(host,[]).append((None, None))
                                        
                                # Add the average value to the plot data, then reset the accumulator
                                if last_sample[host]['count'][sensor['key']] > 0:
                                    data.setdefault(sensor['key'],{}).setdefault(host,[]).append(
                                        (timestamp, last_sample[host]['accumulator'][sensor['key']] / last_sample[host]['count'][sensor['key']])
                                    )
                                    last_sample[host]['accumulator'][sensor['key']] = 0.0
                                    last_sample[host]['count'][sensor['key']] = 0
                        
                            last_sample[host]['timestamp'] = timestamp
        
        this_date += timedelta(days=1)
    
    # Compute X-axis labels based on period
    xlabel = start_date
    xlabels = []
    if period <= 3600:
        xspacing = 300
        xformat = '%-I:%M%p'
    elif period <= 86400:
        xspacing = 3600
        xformat = '%-I%p'
    else:
        xspacing = 86400
        xformat = "%a %-m/%-d/%Y"
        
    while xlabel <= end_date:
        xlabels.append(xlabel)
        xlabel += timedelta(seconds=xspacing)
    
    # Render loop
    charts = {}
    style = pygal.style.Style(
        colors=['red','green','blue','orange','cyan']
    )
    for sensor in sensors:
        charts[sensor['key']] = pygal.DateTimeLine(
            title=sensor['title'],
            x_labels=xlabels,
            x_label_rotation=35, 
            truncate_label=-1,
            x_value_formatter=lambda dt: dt.strftime(xformat),
            y_labels=sensor['ylabels'],
            style=style)
        
        for host in data[sensor['key']].keys():
            charts[sensor['key']].add(
                hosts[host]['name'], 
                data[sensor['key']][host], 
                show_dots=False, 
                allow_interruptions=True)
    
    return render_template(
        'index.html', 
        offset=offset, 
        range=period, 
        temp_chart=charts['temp'].render_data_uri(), 
        humi_chart=charts['humi'].render_data_uri(), 
        press_chart=charts['press'].render_data_uri(), 
        start_date=start_date, 
        end_date=end_date)
