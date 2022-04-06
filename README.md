# temp-humi
This project is an ESP8266/(Si7021,BME280)-based household temperature and humidity monitoring system. There are three components:
- Client program on the ESP8266 which collects the data and sends it out through UDP (In Arduino's C++ dialect)
- Server program which collects the UDP messages from any number of clients into dated CSV files (Shell script calling socat)
- Web program which renders the CSV data (versions in Perl calling GnuPlot and Python calling PyGal)
