
//= require leaflet


$( document ).ready(function() {
    if ( $( "#guardmap" ).length ) {
        var guardmapdiv = $("#guardmap");

        guardmap = L.map('guardmap');
        guardmap.setView([guardmapdiv.data("center-lat"), guardmapdiv.data("center-lon")], guardmapdiv.data("scale")+3);

        guardmap.on('click', function(e) {
            console.log(JSON.stringify(e.latlng));
            $( "#guard_location_longitude").val(e.latlng.lng)
            $( "#guard_location_latitude").val(e.latlng.lat)
        });

        var myIcon = L.icon({
            iconUrl: '/../../assets/control_point_white.png',
            iconSize: [18, 18],
            iconAnchor: [0, 0],
            popupAnchor: [-3, -76]
        });

        $.getJSON(window.location.pathname + '/../../', function (data) {
            for (i=0; i<data.length;i++){

                if(data[i].lat && data[i].lon) {
                    var marker = L.circle([data[i].lat, data[i].lon], {
                        color: 'red',
                        fillColor: 'red',
                        fillOpacity: 0.3,
                        radius: data[i].radius
                    }).addTo(guardmap);
                    var tooltip= L.tooltip({
                        offset:L.point(0,0)
                    })
                    tooltip.setTooltipContent(data[i].name);

                    marker.bindTooltip(data[i].name,{
                        offset:L.point(8,7),
                        direction: 'top',
                        className:data[i].is_gauntlet ? 'cp_tooltip_gt':'cp_tooltip',
                        permanent:true
                    }).openTooltip();

                }
            }
        })

        $.getJSON(window.location.pathname + '/../../../stops', function (data) {

            for (i=0; i<data.length;i++){

                var circle = L.circle([data[i].lat, data[i].lon], {
                    color: 'black',
                    fillColor: 'black',
                    fillOpacity: 0.5,
                    radius: 2
                }).addTo(guardmap);
            }
        });

        var tracks={};
        $.getJSON(window.location.pathname + '/../', function (data) {
            for (i=0; i<data.length;i++){
                trck=L.geoJSON(data[i],{style:{
                    "color": "black",
                    "weight": 1,
                    "opacity": 1
                }});
                trck.addTo(guardmap);
                //tracks[data[i].properties.name]=trck
            }
        })
    }
})