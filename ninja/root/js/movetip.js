
$(document).ready(function() {


$('<div id="livetip"></div>').hide().appendTo('body');
var tipTitle = '';
$('.tablesorter').bind('mouseover', function(evt) {
 var $link = $(evt.target).closest('a');

 if ($link.length) {
   var link = $link[0];
   tipTitle = link.title;
   link.title = '';
   $('#livetip')
   .css({
     top: evt.pageY + 12,
     left: evt.pageX + 12
   })
   .html('<div>' + tipTitle + '</div><div>' + link.href + '</div>')
   .show();
 }

}).bind('mouseout', function(evt) {

 var $link = $(evt.target).closest('a');
 if ($link.length) {
   $link.attr('title', tipTitle);
   $('#livetip').hide();
 }

}).bind('mousemove', function(evt) {
 if ($(evt.target).closest('a').length) {
   $('#livetip').css({
     top: evt.pageY + 12,
     left: evt.pageX + 12
   });
 }
});


});
