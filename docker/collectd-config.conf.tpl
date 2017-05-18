Hostname "{{ HOST_NAME | default("webserver-docker") }}"

FQDNLookup false
Interval 10
Timeout 2
ReadThreads 5

LoadPlugin cpu
LoadPlugin disk
LoadPlugin interface
LoadPlugin load
LoadPlugin memory
LoadPlugin cpu
LoadPlugin write_http

<Plugin write_http>
    <Node "collectd_exporter">
	    URL "{{ COLLECTD_WRITEHTTP_HOST }}"
	    Format "JSON"
	    StoreRates false
    </Node>
</Plugin>
