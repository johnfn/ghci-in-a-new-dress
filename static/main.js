$(function() {
  var BACKSPACE = 8;
  var ENTER     = 13;

  var ticks = 0;

  var blink_cursor = function() {
    ++ticks;
    if (ticks % 3 == 0) {
      /* We don't want to set display: none since then we wouldn't be able to
       * position the autocomplete at the cursor when the cursor was not
       * visible. So we blink the cursor in this way instead. */
      if ($("#cursor").css('color') == 'rgb(255, 255, 255)'){
        $("#cursor").css({'color': 'black'});
      } else {
        $("#cursor").css({'color': 'white'});
      }
    }
  }

  var move_autocomplete = function() {
    var cursor_position = $("#cursor").offset();
    $("#autocomplete").css(cursor_position);
  }

  /* 
   * Generic way to add a new line to the console. `yours` indicates whether it
   * "belongs to you" - i.e., whether the cursor should be on it or not. 
   */
  var add_line = function(content, yours) {
    var $old_elem = $("#active");
    var $new_elem = $old_elem.clone();

    $new_elem.children("#content").html(content);

    if (yours) {
      $("#console").append($new_elem);
      $old_elem.attr("id", ""); //remove #active id.
      $old_elem.children("#cursor").remove();
    } else {
      $new_elem.attr("id", ""); //remove #active id.
      $new_elem.children("#cursor").remove();
      $new_elem.insertBefore($("#console #active"));
      $new_elem.children("#prompt").remove();
    }
  }

  var add_output_line = function(content) {
    add_line(content, true);
  }

  /* Call to insert new output (presumably from ghci) into the console. */
  var receive = function(output) {
    add_line(output, false);
  }

  var starts_with = function(bigger, smaller) {
    if (smaller.length > bigger) return false;
    return bigger.slice(0, smaller.length) == smaller;
  }

  var current_word = function() {
    var current_line = $("#active #content").html();
    return current_line.slice(current_line.lastIndexOf(" ") + 1);
  }

  var show_autocomplete = function(list, is_calltips) {
    $("#autocomplete").children().remove();

    for (var i = 0; i < list.length; i++) {
      if (starts_with(list[i], current_word())) {
        $("#autocomplete").append($("<li><b>" + list[i].slice(0, current_word().length) + "</b>" + list[i].slice(current_word().length, list[i].length) + "</li>"));
      } else {
        $("#autocomplete").append($("<li>" + list[i] + "</li>"));
      }
    }
  }

  /* Call to send output "through the socket" (which is really not a socket at
   * all and is instead just AJAX. */
  var send = function(code) {
    //TODO: AJAX stuff.
    
    add_output_line("");
  }

  var add_to_console = function(value) {
    var $content = $("#active #content");
    var old_html = $content.html();
    var new_html;

    if (value == ENTER) {
      send(old_html);
      return;
    } else if (value == BACKSPACE) {
      if (old_html.length == 0) {
        return;
      }

      new_html = old_html.slice(0, old_html.length - 1);
    } else {
      new_html = old_html + value;
    }

    $content.html(new_html);
    move_autocomplete();
  }

  $(document).bind('keypress', function(e) {
    key = String.fromCharCode(e.which);
    add_to_console(key);
  });

  /* Backspace cannot be detected by a keypress event. */
  $(document).bind('keydown', function(e) {
    if (e.which == BACKSPACE) {
      add_to_console(BACKSPACE);
    } else if (e.which == ENTER) {
      add_to_console(ENTER);
    }
  });

  setInterval(function(){
    show_autocomplete(["one thing", "another thing", "a third thing"], false);
    blink_cursor();
  }, 100);
});
