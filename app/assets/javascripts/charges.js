
//= require leaflet


$( document ).ready(function() {
    if ( $( "#cpmap" ).length ) {
        var cpmapdiv = $("#cpmap");

        cpmap = L.map('cpmap');
        cpmap.setView([cpmapdiv.data("center-lat"), cpmapdiv.data("center-lon")], cpmapdiv.data("scale"));

        L.tileLayer("https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}", {
            attribution: '',
            maxZoom: 17
        }).addTo(cpmap);

        var myIcon = L.icon({
            iconUrl: '../assets/control_point_white.png',
            iconSize: [18, 18],
            iconAnchor: [0, 0],
            popupAnchor: [-3, -76]
        });

        $.getJSON(window.location.pathname + "/guards", function (data) {
            for (i=0; i<data.length;i++){
                console.log(JSON.stringify(data[i]));
                if(data[i].lat && data[i].lon) {
                    var marker = L.marker([data[i].lat, data[i].lon],{icon: myIcon}).addTo(cpmap);
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
    }

})
