var lane_img_n = '';

function update_rects()
{
    /*$('html, body').css({
        'overflow': 'hidden',
        'height': '100%'
    });*/
    
    var cl_name="lane_image";
    $('.'+cl_name).each(function( index )
    {
        //get position of this object
        bounds=this.getBoundingClientRect();
        var left=bounds.left + window.scrollX;
        var top=bounds.top + window.scrollY;  // <-- this is the problem !  need correct bounds even after scroll!
        
        //the absolute location on the page
        var abs_x = event.pageX;
        var abs_y = event.pageY;
        
        //the local location in the image
        var x = abs_x - left;
        var y = abs_y - top;
        
        var cw=this.clientWidth;
        var ch=this.clientHeight;
        var iw=this.naturalWidth;
        var ih=this.naturalHeight;
        var px=x/cw*iw;
        var py=y/ch*ih;
        
        var edge_x = abs_x-x-1;
        var width_rect=cw;
        
        //get the lane id and load bands for lane          
        var id = $(this).attr("id");
        var res = id.split("_");
        var lane_id=res[2];
        var getObj =
        {
                action: "load_bands_for_lane",
                lane: lane_id,
                exclude: 1,
        };
        
        $.post( "../copurification-cgi/copurification.pl", getObj ).done(function( data )
        {
            var res_arr = data.split(",");
            var i=0;
            while (i<(res_arr.length-1))
            {
                var local_top = parseInt(res_arr[i]);
                var local_bottom = parseInt(res_arr[i+1]);
                var height = local_bottom-local_top;
                var abs_top = local_top + top;
                
                $("#lane_div_"+lane_id).append( 
                $('<div/>')
                    .addClass("ui-widget-content rect")  // width_rect
                    .css({"width":"1px", "height":height, "top":abs_top+"px", "left":left+"px", "position":"absolute", "background": "rgb(255, 0, 0)", "border": "1px solid red"})
                ).show();
                
                i=i+2;
            }
            
            /*$('html, body').css({
            'overflow': 'auto',
            'height': 'auto'
            });*/
            
        });
    });
    
    
}

function readyFn(jQuery)
{
    $.ajaxSetup({ cache: false });
    
    update_rects();
}

//$(document).ready(readyFn);

$(window).on("load", readyFn);

