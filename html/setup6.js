var lane_img_n = '';

function readyFn(jQuery)
{
    $.ajaxSetup({ cache: false });
    
    var $allow_clicks=1;
    //if ($('#shared_project').length)
    //{   
    //    $allow_clicks=0;
    //}
    
    if ($allow_clicks)
    {
        $(".lane_img").on("click", function(event)
        { //class for the lane images is lane_img
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
             
            //show confirm box asking if the user would like to add a manual band (yes/no)
            // TODO: change this to not use confirm box so the title can be changed!
            if (confirm("Would you like to add a band in this location?"))
            {
                //get the id/name of the image on which the click occurred - this will tell gel and lane ids
                var id = $(this).attr("id");
                var res = id.split("-");
                var gel_id=res[0];
                var lane_id=res[1];
                
                //show rect at that location, height 1px, width == width of image (lane), allow movement of rect in vertical direction only
                //rect should have indicator for what gel/lane it is on
                $("#gel-"+gel_id).append(
                    $('<div/>')
                        .attr("name", "rect_lane-"+lane_id) 
                        .addClass("ui-widget-content rect rect_gel-"+gel_id) 
                        .css({"width":width_rect+"px", "height":"5px", "top":abs_y+"px", "left":edge_x+"px", "position":"absolute"})
                        .draggable({ containment: '#'+id })
                        .resizable({handles: "n, s", minHeight: 1, minWidth: width_rect+'px', maxWidth: width_rect+'px'})
                ).show();
                
                //enable the buttons for save/remove manual bands for the current gel (if not already enabled)
                $("#save_bands_gel-"+gel_id).prop('disabled',false);
                $("#clear_bands_gel-"+gel_id).prop('disabled',false);
                
                //if rects not already loaded for lane, load all bands and draw rects around them - so the user will not make an overlapping band
                //draw them in blue and make them unmoveable etc
                //submit the request to save_new_bands.pl, which will save to DB
                var getObj =
                {
                        action: "load_bands_for_lane",
                        lane: lane_id,
                        exclude: 0,
                };
                
                $.post( "../copurification-cgi/copurification.pl", getObj ).done(function( data )
                {
                    //alert(data);
                    var res_arr = data.split(",");
                    var i=0;
                    while (i<(res_arr.length-1))
                    {
                        var local_top = parseInt(res_arr[i]);
                        var local_bottom = parseInt(res_arr[i+1]);
                        var height = local_bottom-local_top;
                        var abs_top = local_top + top;
                        
                        $("#gel-"+gel_id).append(
                        $('<div/>')
                            .addClass("ui-widget-content rect imagemap-rect_gel-"+gel_id) 
                            .css({"width":width_rect+"px", "height":height, "top":abs_top+"px", "left":left+"px", "position":"absolute", "background": "rgba(255, 255, 255, 0)", "border": "1px solid blue"})
                        ).show();
                        
                        i=i+2;
                    }
                });
            }
        });
    
        $('.save_bands_button').click(function( )
        {
            if (confirm("Save all new bands for this gel?"))
            {
                
                //gather all rects for this gel, save to DB and reload page
                var button_id = $(this).attr("id");
                var res = button_id.split("-");
                var gel_id = res[1];
                
                //start the data for post 
                var getObj =
                {
                        action: 'save_manual_bands',
                        snb_gel: gel_id,
                        norm_img_str: lane_img_n,
                };
                
                //alert("getObj="+getObj['action']+' '+getObj['snb_gel']+' '+getObj['norm_img_str']);
                
                //loop through all rects on this gel
                //collect lane-id and start and end (x) position of band
                var lane_str = '';
                var top_str = '';
                var height_str = '';
                $(".rect_gel-"+gel_id).each(function( index )
                {
                        var rect_name = $(this).attr("name");
                        var res = rect_name.split("-");
                        var lane_id = res[1];
                        var pos = $( this ).position();
                        var lane_img_id = gel_id+'-'+lane_id
                        var parent_pos = $('#'+lane_img_id+lane_img_n).position();
                        var top = Math.round(pos.top - parent_pos.top);
                        var height = Math.round($( this ).height());
                        
                        //alert(lane_id+' '+top+' '+height);
                        
                        if (index == 0)
                        {
                            lane_str = lane_id;
                            top_str = top;
                            height_str = height;
                        }
                        else
                        {
                            lane_str = lane_str + '-' + lane_id;
                            top_str = top_str + '-' + top;
                            height_str = height_str + '-' + height;
                        }
                });
                
                getObj['snb_lanes_list'] = lane_str;
                getObj["snb_tops_list"] = top_str;
                getObj["snb_heights_list"] = height_str;
                
                if (true)
                {
                    //submit the request to save_new_bands.pl, which will save to DB
                    $.post( "../copurification-cgi/copurification.pl", getObj ).done(function( data )
                    {
                            //alert( "Data Loaded: " + data );
                            $('#exp_results_table').replaceWith(data);
                            readyFn();
                            
                            //clear rects that have been saved
                            $(".rect_gel-"+gel_id).remove();
                            
                            //disable buttons
                            $("#save_bands_gel-"+gel_id).prop('disabled',true);
                            $("#clear_bands_gel-"+gel_id).prop('disabled',true);
                            
                            //alert("Band(s) saved!")
                    });
                }
            }  
        });
    
        $('.clear_bands_button').click(function( )
        {
            if (confirm("Clear all unsaved bands on this gel?"))
            {
                var button_id = $(this).attr("id");
                var res = button_id.split("-");
                var gel_id = res[1];
                
                //gather all rects for this gel, remove them
                $(".rect_gel-"+gel_id).remove();
                $(".imagemap-rect_gel-"+gel_id).remove();
                
                
                //disable buttons
                $("#save_bands_gel-"+gel_id).prop('disabled',true);
                $("#clear_bands_gel-"+gel_id).prop('disabled',true);
            }
                
        });
    }
    
}

$(document).ready(readyFn);

