var djot = {};
var initialized = false;

Module['onRuntimeInitialized'] = () => {
  const djot_open = Module.cwrap("djot_open", "number", []);
  const djot_close = Module.cwrap("djot_open", null, ["number"]);
  djot.state = djot_open();
  const djot_to_ast_json =
      Module.cwrap("djot_to_ast_json", "string" ,["number", "string", "boolean"]);
  djot.to_ast_json = (s, sourcepos) => {
    return djot_to_ast_json(djot.state, s, sourcepos);
  }
  const djot_to_ast_pretty =
      Module.cwrap("djot_to_ast_pretty", "string" ,["number", "string", "boolean"]);
  djot.to_ast_pretty = (s, sourcepos) => {
    return djot_to_ast_pretty(djot.state, s, sourcepos);
  }
  const djot_to_matches_json =
      Module.cwrap("djot_to_matches_json", "string" ,["number", "string"]);
  djot.to_matches_json = (s) => {
    return djot_to_matches_json(djot.state, s);
  }
  const djot_to_matches_pretty =
      Module.cwrap("djot_to_matches_pretty", "string" ,["number", "string"]);
  djot.to_matches_pretty = (s) => {
    return djot_to_matches_pretty(djot.state, s);
  }
  const djot_to_html =
      Module.cwrap("djot_to_html", "string" ,["number", "string", "boolean"]);
  djot.to_html = (s, sourcepos) => {
    return djot_to_html(djot.state, s, sourcepos);
  }
  const input = document.getElementById("input");
  input.onkeyup = debounce(convert, 400);
  input.onscroll = syncScroll;
  document.getElementById("mode").onchange = convert;
  document.getElementById("sourcepos").onchange = convert;
  convert();
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
      elt.scrollIntoView(true);
    }
  }
}



const inject = (iframe, html) => {
  const doc = iframe.contentDocument;
  if (doc) {
    const body = doc.querySelector("#htmlbody");
    if (body) body.innerHTML = html;
    iframe.contentWindow.MathJax.typeset();
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

function convert() {
  const mode = document.getElementById("mode").value;
  const text = document.getElementById("input").value;
  const iframe = document.getElementById("preview");
  const sourcepos = document.getElementById("sourcepos").checked;
  document.getElementById("result").innerHTML = "";

  if (mode == "astjson") {
    document.getElementById("result").innerText =
      JSON.stringify(JSON.parse(djot.to_ast_json(text, sourcepos)), null, 2);
  } else if (mode == "ast") {
    document.getElementById("result").innerText =
      djot.to_ast_pretty(text, sourcepos);
  } else if (mode == "matches") {
    document.getElementById("result").innerText =
      djot.to_matches_pretty(text);
  } else if (mode == "matchesjson") {
    document.getElementById("result").innerText =
      JSON.stringify(JSON.parse(djot.to_matches_json(text)), null, 2);
  } else if (mode == "html") {
    document.getElementById("result").innerText = djot.to_html(text, sourcepos);
  } else if (mode == "preview") {
    inject(iframe, djot.to_html(text, true));  // use sourcepos for scrollSync
  }
  iframe.style.display = mode == "preview" ? "block" : "none";
}
