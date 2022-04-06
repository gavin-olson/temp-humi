from flask import Flask
from flask import request
from flask import render_template
from flask import send_file

import pygal
import os

from datetime import date
from datetime import datetime
from datetime import timedelta

from collections import Counter

import pandas as pd

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
    app.logger.info(f"end_date => {end_date}")
    if period >= 86400:
        end_date = end_date.replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(days=1)
    app.logger.info(f"end_date => {end_date}")
    start_date = end_date - timedelta(seconds=period)
    app.logger.info(f"start_date => {start_date}")
    
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
    data = pd.DataFrame()
    while this_date <= end_date:
        this_filename = f"/var/log/temp-humi-{this_date.strftime('%Y-%m-%d')}.dat"
        app.logger.info(f"data file => {this_filename}")
        if os.path.isfile(this_filename):
            app.logger.info("data file is a file")
            data = pd.concat([data, pd.read_csv(
                this_filename,
                header=None,
                names=('timestamp', 'host', 'temp', 'temp_u', 'humi', 'humi_u', 'batt', 'batt_u', 'press', 'press_u'),
                usecols=('timestamp', 'host', 'temp', 'humi', 'press'),
                parse_dates=['timestamp'],
                date_parser=lambda x: datetime.fromtimestamp(int(x)),
                dtype={'temp':float, 'humi':float, 'press':float}
                )])
        this_date += timedelta(days=1)
    
    # Prune data
    data = data[data['timestamp'].between(start_date, end_date)]
    
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
        
        for host in hosts.keys():
            charts[sensor['key']].add(
                hosts[host]['name'], 
                list(data
                     .loc[data['host'] == host, ['timestamp',sensor['key']]]
                     .resample('1H', on='timestamp')
                     .mean()
                     .fillna(value=0)
                     .itertuples()),
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
