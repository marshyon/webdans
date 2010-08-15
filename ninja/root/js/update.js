function update_table_checkboxes() {

        var classRegExpCheckbox = /(<input.+?id="(checkbx_\d+-(.+?))".+?checkbox.+>)/;
        var classResultCheckbox;
        var classRegExpChecked = /checked="yes"/;

        $('.tablesorter td').each(function() {

            var node = $(this);
            var html = node.html();

            if (classResultCheckbox = classRegExpCheckbox.exec(html)) {

                var id_str = '#' + classResultCheckbox[2];
                if( hashUriMods[classResultCheckbox[3]] == 'add' ) {
                    $(id_str).attr('checked', true);
                }
                else {
                    $(id_str).attr('checked', false);
                }
            }
        });
}
