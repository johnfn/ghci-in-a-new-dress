$(function() {
  var BACKSPACE = 8;
  var TAB       = 9;
  var ENTER     = 13;

  var ticks = 0;
  var autocomplete_info = {};

  var showing_calltips = false;
  var calltips_word = "";

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

  var move_calltips_box = function() {
    var cursor_position = $("#cursor").offset();
    //No idea why I have to offset this one but not the other.

    cursor_position.top += 18;
    $("#calltips").css(cursor_position);
  }

  var move_autocomplete = function() {
    var cursor_position = $("#cursor").offset();
    $("#autocomplete").css(cursor_position);
  }

  var list_to_dict = function(list) {
    var result = {};
    for (var i = 0; i < list.length; i++){
      result[list[i]] = true;
    }
    return result;
  }

  var dict_to_list = function(dict) {
    var result = [];
    for (var x in dict) {
      result.push(x);
    }
    return result;
  }

  var surround_keyword = function(word) {
    return "<span class='keyword'>" + word + "</span>";
  }

  var add_colors = function(element) {
    var contents = element.html().split(' ');
    var keyword_list = [ 'if', 'then', 'else' ];
    var keyword_dict = list_to_dict(keyword_list);
    var result_text = "";

    for (var i = 0; i < contents.length; i++) {
      var word = $.trim(contents[i]);

      if (word in keyword_dict) {
        result_text += surround_keyword(word);
      } else {
        result_text += word;
      }
      result_text += " ";
    }

    element.html(result_text);
  }

  /* 
   * Generic way to add a new line to the console. `yours` indicates whether it
   * "belongs to you" - i.e., whether the cursor should be on it or not. 
   */
  var add_line = function(content, yours) {
    var $old_elem = $("#active");
    var $new_elem = $old_elem.clone();

    if (yours) {
      $("#console").append($new_elem);
      $old_elem.attr("id", ""); //remove #active id.
      $old_elem.children("#cursor").remove();
      add_colors($old_elem.children("#content"));
      $new_elem.children("#content").html("");
    } else {
      $new_elem.children("#content").html(content);
      $new_elem.attr("id", ""); //remove #active id.
      $new_elem.children("#cursor").remove();
      $new_elem.insertBefore($("#console #active"));
      $new_elem.children("#prompt").remove();
      add_colors($new_elem.children("#content"));
    }
  }

  /* sends `content` as an ajax request to `link`, calling `callback`
   * when we receive data from the request. */
  var send_to_server = function(content, callback) {
    var strip_and_callback = function(content) {
      var initial_crap = "<!DOCTYPE html>\n <html><head><title></title></head><body>";
      var final_crap   = "</body></html>";

      var stripped_content = content.slice(initial_crap.length, content.length - final_crap.length);
      callback(stripped_content);
    }

    $.ajax({
      type: 'POST',
      url: "/ghci",
      data: {'data' : content},
      success: strip_and_callback
    });
  }

  /* TODO: Should also be called when user loads in new modules. */
  var populate_autocomplete = function() {
    send_to_server(":browse", function(data){
      var lines = data.split("\n");
      for (var i = 0; i < lines.length; i++){
        var line = lines[i];
        //autocomplete_info["map"] = "(a -> b) -> [a] -> [b]"

        var browse_info = /(.+) :: (.+)/g;
        var match = browse_info.exec(line);
        if (match === null) continue;

        autocomplete_info[match[1]] = match[2];
      }
    });
  }

  var add_output_line = function(content) {
    add_line(content, true);
    send_to_server(content, function(data){
      add_line(data, false);
    });
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
    var autocomplete_visible = false;
    if (showing_calltips) {
      $("#autocomplete").hide();
      return;
    }

    $("#autocomplete").children().remove();

    //TODO: Sort alphabetically.
    for (var i = 0; i < list.length; i++) {
      if (starts_with(list[i], current_word())) {
        autocomplete_visible = true;

        $("#autocomplete").append($("<li><b>" + list[i].slice(0, current_word().length) + "</b>" + list[i].slice(current_word().length, list[i].length) + "</li>"));
      }
    }

    if (current_word() == "") {
      autocomplete_visible = false;
    }

    if (autocomplete_visible) {
      $("#autocomplete").show();
    } else {
      $("#autocomplete").hide();
    }

    if (autocomplete_visible) {
      move_autocomplete();
    }
  }

  var autocomplete = function() {
    var completed_word = $($("#autocomplete :first-child")[0]).text();
    var rest = completed_word.slice(current_word().length);
    $("#active #content").html($("#active #content").html() + rest + " ");

    showing_calltips = true;
    calltips_word = $.trim(completed_word);
    move_calltips_box();
  }

  /* Call to send output "through the socket" (which is really not a socket at
   * all and is instead just AJAX. */
  var add_to_console = function(value) {
    var $content = $("#active #content");
    var old_html = $content.html();
    var new_html;

    if (value == ENTER) {
      add_output_line(old_html);
      showing_calltips = false;
      return;
    } else if (value == BACKSPACE) {
      if (old_html.length == 0) {
        return;
      }

      new_html = old_html.slice(0, old_html.length - 1);
    } else if (value == TAB) { 
      autocomplete();
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
    } else if (e.which == TAB) {
      e.preventDefault();
      autocomplete();
    }
  });

  var show_calltips = function() {
    if (!showing_calltips) {
      $("#calltips").hide();
      return;
    }
    $("#calltips").show();
    $("#calltips").html(autocomplete_info[calltips_word]);
    
  }

  setInterval(function(){
    show_autocomplete(dict_to_list(autocomplete_info), false);
    show_calltips();
    blink_cursor();
  }, 100);

  function initialize() {
    populate_autocomplete();
  }

  initialize();
});
