var djot = {};
var initialized = false;

var filterExamples =
  { "capitalize_text":
`-- This filter capitalizes regular text, leaving code and URLs unaffected
return {
  str = function(el)
    el.text = el.text:upper()
  end
}`
  , "empty_filter":
`return {
}`
  , "capitalize_emph":
`-- This filter capitalizes the contents of emph
-- nodes instead of italicizing them.
local capitalize = 0
return {
   emph = {
     enter = function(e)
       capitalize = capitalize + 1
     end,
     exit = function(e)
       capitalize = capitalize - 1
       e.tag = "span"
     end,
   },
   str = function(e)
     if capitalize > 0 then
       e.text = e.text:upper()
      end
   end
}`
  , "multiple_filters":
`-- This filter includes two sub-filters, run in sequence
return {
  { -- first filter changes (TM) to trademark symbol
    str = function(e)
      e.text = e.text:gsub("%(TM%)", "™")
    end
  },
  { -- second filter changes '[]' to '()' in text
    str = function(e)
      e.text = e.text:gsub("%(","["):gsub("%)","]")
    end
  }
}`,
  "letter_enumerated_lists_to_roman":
`-- Changes letter-enumerated lists to roman-numbered
return {
  list = function(e)
    if e.list_style == 'a.' then
      e.list_style = 'i.'
    elseif e.list_style == 'A.' then
      e.list_style = 'I.'
    end
  end
}`
  };

Module['onRuntimeInitialized'] = () => {
  const djot_open = Module.cwrap("djot_open", "number", []);
  const djot_close = Module.cwrap("djot_open", null, ["number"]);
  djot.state = djot_open();

  const djot_get_error = Module.cwrap("djot_get_error", "string" ,["number"]);

  const djot_parse =
      Module.cwrap("djot_parse", null, ["number", "string", "boolean"]);
  djot.parse = (s, sourcepos) => {
      let res = djot_parse(djot.state, s, sourcepos);
      if (res === 0) {
        return "djot.parse error:\n" + djot_get_error(djot.state);
      } else {
        return res;
      }
  }

  const djot_render_ast_pretty =
      Module.cwrap("djot_render_ast_pretty", "string" ,["number"]);
  const djot_render_ast_json =
      Module.cwrap("djot_render_ast_json", "string" ,["number"]);
  djot.render_ast = (as_json) => {
    if (as_json) {
      let res = djot_render_ast_json(djot.state, as_json);
      if (res === 0) {
        return "djot.render_ast error:\n" + djot_get_error(djot.state);
      } else {
        return res;
      }
    } else {
      let res = djot_render_ast_pretty(djot.state, as_json);
      if (res === 0) {
        return "djot.render_ast error:\n" + djot_get_error(djot.state);
      } else {
        return res;
      }
    }
  }

  const djot_apply_filter =
      Module.cwrap("djot_apply_filter", "number" ,["number", "string"]);
  djot.apply_filter = (filter) => {
    if (!djot_apply_filter(djot.state, filter)) {
      let err = djot_get_error(djot.state);
      return err;
    }
    return null;
  }

  const djot_parse_and_render_events =
      Module.cwrap("djot_parse_and_render_events", "string" ,["number", "string"]);
  djot.parse_and_render_events = (s) => {
    let res = djot_parse_and_render_events(djot.state, s);
    if (res === 0) {
      return "djot.parse_and_render_events error:\n" + djot_get_error(djot.state)
    } else {
      return res;
    }
  }

  const djot_render_html =
      Module.cwrap("djot_render_html", "string" ,["number"]);
  djot.render_html = () => {
    let res = djot_render_html(djot.state);
    if (res === 0) {
      return "djot.render_html error:\n" + djot_get_error(djot.state);
    } else {
      return res;
    }
  }
  const input = document.getElementById("input");
  input.onkeyup = debounce(parse_and_render, 400);
  input.onscroll = syncScroll;
  document.getElementById("mode").onchange = render;
  document.getElementById("sourcepos").onchange = parse_and_render;

  document.getElementById("filter-examples").onchange = (e) => {
    let examp = filterExamples[e.target.value];
    document.getElementById("filter").value = examp;
  }

  /* filter modal */
  var modal = document.getElementById("filter-modal");
  // Get the button that opens the modal
  var btn = document.getElementById("filter-open");
  // Get the <span> element that closes the modal
  var span = document.getElementById("filter-close");
  // When the user clicks on the button, open the modal
  btn.onclick = function() {
    modal.style.display = "block";
  }
  // When the user clicks on <span> (x), close the modal
  span.onclick = function() {
    modal.style.display = "none";
    parse_and_render();
  }
  // When the user clicks anywhere outside of the modal, close it
  window.onclick = function(event) {
    if (event.target == modal) {
      modal.style.display = "none";
      parse_and_render();
    }
  }
  parse_and_render();
}

// scroll the preview window to match the input window.
const syncScroll = () => {
  const mode = document.getElementById("mode").value;
  if (mode == "preview") {
    const textarea = document.getElementById("input");
    const iframe = document.getElementById("preview");
    const previewdoc = iframe.contentDocument;
    const preview = previewdoc.querySelector("#htmlbody");
    const lineHeight = parseFloat(window.getComputedStyle(textarea).lineHeight);
    // NOTE this assumes we don't have wrapped lines,
    // so we have set white-space:nowrap on the textarea:
    const lineNumber = Math.floor(textarea.scrollTop / lineHeight) + 1;
    const selector = '[data-startpos^="' + lineNumber + ':"]';
    const elt = preview.querySelector(selector);
    if (elt) {
      elt.scrollIntoView({ behavior: "smooth",
                           block: "start",
                           inline: "nearest" });
    }
  }
}



const inject = (iframe, html) => {
  const doc = iframe.contentDocument;
  if (doc) {
    const body = doc.querySelector("#htmlbody");
    if (body) body.innerHTML = html;
  }
}

const debounce = (func, delay) => {
    let debounceTimer
    return function() {
        const context = this
        const args = arguments
            clearTimeout(debounceTimer)
                debounceTimer
            = setTimeout(() => func.apply(context, args), delay)
    }
}

function parse_and_render() {
  const text = document.getElementById("input").value;
  const sourcepos = document.getElementById("sourcepos").checked;
  const filter = document.getElementById("filter").value;
  var startTime = new Date().getTime();
  if (djot.parse(text, sourcepos)) {
    if (filter && filter != "") {
      let err = djot.apply_filter(filter);
      if (err == null) {
        document.getElementById("filter-error").innerText = "";
        render();
      } else {
        document.getElementById("filter-error").innerText = err;
        /* open filter so they can edit some more and see error message */
        document.getElementById("filter-modal").style.display = "block";
        filter.style.display = "block";
      }
    } else {
      render();
    }
  } else {
    console.log("djot.parse failed.");
  }
  var endTime = new Date().getTime();
  var elapsedTime = endTime - startTime;
  document.getElementById("elapsed-time").innerText = elapsedTime;
  document.getElementById("kbps").innerText = ((text.length / elapsedTime)).toFixed(1);
  document.getElementById("timing").style.visibility = "visible";
}

function render() {
  const text = document.getElementById("input").value;
  const mode = document.getElementById("mode").value;
  const iframe = document.getElementById("preview");
  document.getElementById("result").innerHTML = "";
  const result = document.getElementById("result");

  if (mode == "astjson") {
    result.innerText =
      JSON.stringify(JSON.parse(djot.render_ast(true)), null, 2);
  } else if (mode == "ast") {
    result.innerText =
      djot.render_ast(false);
  } else if (mode == "events") {
    result.innerText =
      djot.parse_and_render_events(text);
  } else if (mode == "html") {
    result.innerText = djot.render_html();
  } else if (mode == "preview") {
    inject(iframe, djot.render_html());  // use sourcepos for scrollSync
  }
  iframe.style.display = mode == "preview" ? "block" : "none";
  result.style.display = mode == "preview" ? "none" : "block";
}
