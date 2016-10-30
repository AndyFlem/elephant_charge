
//= require leaflet


$( document ).ready(function() {
    if ( $( "#entrymap" ).length ) {
        var cpmapdiv = $("#entrymap");

        cpmap = L.map('entrymap');
        cpmap.setView([cpmapdiv.data("center-lat"), cpmapdiv.data("center-lon")], cpmapdiv.data("scale")+1);

        L.tileLayer("https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}", {
            attribution: '',
            maxZoom: 22
        }).addTo(cpmap);

        var myIcon = L.icon({
            iconUrl: '/../../assets/control_point_white.png',
            iconSize: [18, 18],
            iconAnchor: [0, 0],
            popupAnchor: [-3, -76]
        });


        $.getJSON(window.location.pathname + "/../../guards", function (data) {
            for (i=0; i<data.length;i++){
                //console.log(JSON.stringify(data[i]));
                if(data[i].lat && data[i].lon) {
                    var marker = L.circle([data[i].lat, data[i].lon], {
                        color: 'red',
                        fillColor: 'red',
                        fillOpacity: 0.3,
                        radius: data[i].radius
                    }).addTo(cpmap);

                    //var marker = L.marker([data[i].lat, data[i].lon],{icon: myIcon}).addTo(cpmap);
                    var tooltip= L.tooltip({
                        offset:L.point(0,0)
                    })
                    tooltip.setTooltipContent(data[i].name);

                    marker.bindTooltip(data[i].name,{
                        offset:L.point(0,0),
                        direction: 'top',
                        className:data[i].is_gauntlet ? 'cp_tooltip_gt':'cp_tooltip',
                        permanent:true
                    }).openTooltip();

                }
            }
        })

        $.getJSON(window.location.pathname + "/geojson", function (data) {

            L.geoJSON(data,{style:{
                "color": "#ff7800",
                "weight": 2,
                "opacity": 1
            }}).addTo(cpmap);
        })
    }
})