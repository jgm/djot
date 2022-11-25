var djot = {};
var initialized = false;

Module['onRuntimeInitialized'] = () => {
  const djot_open = Module.cwrap("djot_open", "number", []);
  const djot_close = Module.cwrap("djot_open", null, ["number"]);
  djot.state = djot_open();
  const djot_parse =
      Module.cwrap("djot_parse", null, ["number", "string", "boolean"]);
  djot.parse = (s, sourcepos) => {
    return djot_parse(djot.state, s, sourcepos);
  }

  const djot_render_ast =
      Module.cwrap("djot_render_ast", "string" ,["number", "boolean"]);
  djot.render_ast = (as_json) => {
    return djot_render_ast(djot.state, as_json);
  }

  const djot_render_matches =
      Module.cwrap("djot_render_matches", "string" ,["number", "string", "boolean"]);
  djot.render_matches = (s, as_json) => {
    return djot_render_matches(djot.state, s, as_json);
  }

  const djot_render_html =
      Module.cwrap("djot_render_html", "string" ,["number"]);
  djot.render_html = () => {
    return djot_render_html(djot.state);
  }
  const input = document.getElementById("input");
  input.onkeyup = debounce(parse_and_render, 400);
  input.onscroll = syncScroll;
  document.getElementById("mode").onchange = render;
  document.getElementById("sourcepos").onchange = parse_and_render;
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
  if (djot.parse(text, sourcepos)) {
    render();
  } else {
    console.log("djot.parse failed.");
  }
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
  } else if (mode == "matchesjson") {
    result.innerText =
      djot.render_matches(text, true);
  } else if (mode == "matches") {
    result.innerText =
      djot.render_matches(text, false);
  } else if (mode == "html") {
    result.innerText = djot.render_html();
  } else if (mode == "preview") {
    inject(iframe, djot.render_html());  // use sourcepos for scrollSync
  }
  iframe.style.display = mode == "preview" ? "block" : "none";
  result.style.display = mode == "preview" ? "none" : "block";
}
