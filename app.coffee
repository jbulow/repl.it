$ = jQuery

# Global REPLIT container.
@REPLIT = {}

# Module global variables.
jqconsole = null
jsrepl = null
current_lang = null
$doc = null
templates = {}
Languages = {}
examples = []

Init = ->
  # Module global jQuery document object.
  $doc = $(document)
  
  # Define language selection templates
  templates.category = '''
    <h3>{{name}}</h3>
    <ul>
      {{#languages}}
        <li><a data-langname="{{jsrepl_name}}">{{{display}}}</a></li>
      {{/languages}}
    </ul>
  '''
  templates.languages = '''
    <h2>Please Select Your Language</h2>
    <div class="cat-list">
      {{#categories}}
        <div class="category">
          {{>category}}
        </div>
      {{/categories}}
    </div>
  '''
  
  # Define example template
  templates.examples = '''
    <ul>
    {{#examples}}
      <li><a href="#" data-index={{index}}>{{title}}</a></li>
    {{/examples}}
    </ul>
  '''
  
  # Instantiate jqconsole
  jqconsole = $('#console').jqconsole ''
  
  # Load replit language settings
  categories = []
  for name, languages of @REPLIT.Languages
    for lang in languages
      Languages[lang.jsrepl_name] = lang
      lang.display = ()->
        index = this.name.indexOf this.shortcut
        # Warning slicing strings.
        return this.name[...index] + 
                "<span>#{this.name.charAt(index)}</span>" + 
                this.name[index+1...]
    categories.push {
      name
      languages
    }
    
  # Render language selection templates
  lang_sel_html = Mustache.to_html templates.languages, {categories}, templates
  $('#language-selector').append lang_sel_html
  
# Shows a command prompt in the console and waits for input.
StartPrompt = ->
  console.log jqconsole.input_queue
  Evaluate = (command)->
    if command
      jsrepl.Evaluate command
    else
      StartPrompt()
  jqconsole.Prompt true, Evaluate, $.proxy(jsrepl.CheckLineEnd, jsrepl)

# Load a given language by name.
LoadLanguage = (lang_name) ->
  $.nav.pushState "/#{lang_name.toLowerCase()}"
  
  # Do the actual language loading.

# Sets up the HashChange event handler. Handles cases were user is not
# entering language in correct case.
SetupURLHashChange = ->
  langs = {}
  for lang_name, lang of Languages
    langs[lang_name.toLowerCase()] = lang;
  jQuery.nav (lang_name, link) ->
    if langs[lang_name]?
      lang_name = langs[lang_name].jsrepl_name
      # TODO(amasad): Create a loading effect.
      $('body').toggleClass 'loading'

      # Module global current language
      current_lang = JSREPL::Languages::[lang_name]

      # Register charecter matchings in jqconsole for the current language
      i = 0
      for [open, close] in current_lang.matchings
        jqconsole.RegisterMatching open, close, 'matching-' + (++i)

      # Load examples.  
      $.get Languages[lang_name].example_file, (raw_examples) =>
        # Clear the existing examples.
        examples = []
        # Parse out the new examples.
        example_parts = raw_examples.split /\*{80}/
        title = null
        for part in example_parts
          part = part.replace /^\s+|\s*$/g, ''
          if not part then continue
          if title
            code = part
            examples.push {
              title
              code
              index: examples.length
            }
            title = null
          else
            title = part

        # Render examples.
        examples_sel_html = Mustache.to_html templates.examples, {examples}
        $('#examples-selector').empty().append examples_sel_html
        # Set up response to example selection.

      # Empty out the history, prompt and example selection.
      jqconsole.Reset()
      jqconsole.RegisterShortcut 'Z', =>
        jqconsole.AbortPrompt()
        StartPrompt()
      jsrepl.LoadLanguage lang_name, =>
        $('body').toggleClass 'loading'
        StartPrompt()

# Overlays container.
# Methods responsible for UI and behavior of overlays.
Overlays =
  # Langauge selection overlay method.
  languages: ()->
    selected = false
    jQuery.facebox {div: '#language-selector'}, 'languages'
    $('#facebox .content.languages .cat-list span').each (i, elem)->
      $elem = $(elem)
      $doc.bind 'keyup.languages', (e)->
        upperCaseCode = $elem.text().toUpperCase().charCodeAt(0)
        lowerCaseCode = $elem.text().toLowerCase().charCodeAt(0)
        if e.keyCode == upperCaseCode or e.keyCode == lowerCaseCode
          $doc.trigger 'close.facebox'
          selected = true
          LoadLanguage $elem.parent().data 'langname'
    
    $doc.bind 'close.facebox.languages', ()=>
      $doc.unbind 'keyup.languages'
      $doc.unbind 'close.facebox.languages'
      StartPrompt() if not selected
      
    jqconsole.AbortPrompt() if jqconsole.state == 2
    
  examples: ()->
    jQuery.facebox {div: '#examples-selector'}, 'examples'
    $('#facebox .content.examples ul a').click (e)->
      e.preventDefault()
      example = examples[$(this).data 'index']
      $doc.trigger 'close.facebox'
      jqconsole.SetPromptText example.code
      jqconsole.Focus()
      
$ ->
  config = 
    JSREPL_dir: 'jsrepl/'
    # Receives the result of a command evaluation.
    #   @arg result: The user-readable string form of the result of an evaluation.
    ResultCallback: (result) ->
      if result
        jqconsole.Write '==> ' + result, 'result'
      StartPrompt()
    
    # Receives an error message resulting from a command evaluation.
    #   @arg error: A message describing the error.
    ErrorCallback: (error) ->
      jqconsole.Write String(error), 'error'
      StartPrompt()
      
    # Receives any output from a language engine. Acts as a low-level output
    # stream or port.
    #   @arg output: The string to output. May contain control characters.
    #   @arg cls: An optional class for styling the output.
    OutputCallback: (output, cls) ->
      jqconsole.Write output, cls
      return undefined
      
    # Receives a request for a string input from a language engine. Passes back
    # the user's response asynchronously.
    #   @arg callback: The function called with the string containing the user's
    #     response. Currently called synchronously, but that is *NOT* guaranteed.
    InputCallback: (callback) ->
      jqconsole.Input (result) =>
        try
          callback result
        catch e
          @ErrorCallback e
      return undefined
    
  jsrepl = new JSREPL config
  window.jsrepl = jsrepl
  Init()

  $(window).load () ->
    # Hack for chrome and FF 4 fires an additional popstate on window load.
    setTimeout SetupURLHashChange, 0
  $doc.keyup (e)->
    # Escape key
    if e.keyCode == 27 and not $('#facebox').is(':visible')
      Overlays.languages()
      
  $('#examples-button').click (e)->
    e.preventDefault()
    Overlays.examples()
    
  $('#languages-button').click (e)->
    e.preventDefault()
    Overlays.languages()
      