// hide ok dialogues 




$(document).ready(function() {

            $("#ok-dialog-message").hide();
            $("#dialog-message").hide();
            $('#disclaimer').hide();

            var numberOfRows = $('.tablesorter tr').length;

            $(function() {
                var sorting = [[2,1],[3,0]]; 
                $("table")
                        .tablesorter({widthFixed: true, widgets: ['zebra']})
                        .trigger("sorton",[sorting])
                        .tablesorterPager({container: $("#pager")}) 
            });

            var height = $('.tablesorter').height() + 70;
            if(height < 395) { height = 395; }
            $('#mainContent').height(height);
            //console.log('onload height is ', height, ' and rows are at ', numberOfRows);

            $('.pagesize').click(function() {
                var height = $('.tablesorter').height() + 70;
                $('#mainContent').height(height);
            });

            $('#toggleButton').click(function() {
                $('#disclaimer').slideToggle('slow');
            //    var txt = $('.ui-button-text').html();
            //    if(txt == 'help') {
            //        $('.ui-button-text').html('hide help');
            //    }
            //    else {
            //        $('.ui-button-text').html('help');
            //    }
            });
});


