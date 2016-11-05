
//= require leaflet


$( document ).ready(function() {
    if ( $( "#legmap" ).length ) {
        var legmapdiv = $("#legmap");

        legmap = L.map('legmap');
        legmap.setView([legmapdiv.data("center-lat"), legmapdiv.data("center-lon")], legmapdiv.data("scale"));

        L.tileLayer("https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}", {
            attribution: '',
            maxZoom: 22
        }).addTo(legmap);


        $.getJSON(window.location.pathname + '/../../guards/', function (data) {
            for (i=0; i<data.length;i++){

                if(data[i].lat && data[i].lon) {
                    var marker = L.circle([data[i].lat, data[i].lon], {
                        color: 'green',
                        fillColor: 'green',
                        fillOpacity: 0.3,
                        radius: data[i].radius
                    }).addTo(legmap);
                    var tooltip= L.tooltip({
                        offset:L.point(0,0)
                    })
                    tooltip.setTooltipContent(data[i].name);

                    marker.bindTooltip(data[i].name,{
                        offset:L.point(8,7),
                        direction: 'top',
                        className:(data[i].id==legmapdiv.data("guard1-id") || data[i].id==legmapdiv.data("guard2-id")) ? 'cp_tooltip_gt':'cp_tooltip',
                        permanent:true
                    }).openTooltip();

                }
            }
        })

        var tracks={};
        $.getJSON(window.location.pathname, function (data) {
            for (i=0; i<data.length;i++){
                trck=L.geoJSON(data[i],{
                    style:{
                        "color": "black",
                        "weight": 1,
                        "opacity": 0.7
                    },
                    onEachFeature: function (feature, layer) {
                        console.dir(feature.properties.name)
                        tracks[feature.properties.name]=layer;
                    }
                });
                trck.addTo(legmap);
                //tracks[data[i].properties.name]=trck
            }
        })

        $("[id|='entry']").click(function(e) {
            console.dir(e.target)
            for (var key in tracks) {
                if (tracks.hasOwnProperty(key)) {
                    tracks[key].setStyle({
                        color: 'black',
                        weight: 1,
                        "opacity": 0.7
                    });
                }
            }

            entry_id= e.target.id.split('-')[1];
            layer=tracks[entry_id]
            layer.setStyle({
                color: 'red',
                weight: 2,
                "opacity": 1
            });
        });

    }
})