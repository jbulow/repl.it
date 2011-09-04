# Responsible for DOM initializations, and most interactions.

# Core module.

CONTENT_PADDING = 200
FOOTER_HEIGHT = 30
HEADER_HEIGHT = 61
RESIZER_WIDTH = 8
DEFAULT_SPLIT = 0.5
CONSOLE_HIDDEN = 1
EDITOR_HIDDEN = 0
$ = jQuery

# jQuery plugin to disable text selection (x-browser).
# Used for one dragging the resizer.
$.fn.disableSelection = ->
  @each ->
    $this = $(this)
    $this.attr 'unselectable', 'on'
    $this.css
      '-moz-user-select':'none'
      '-webkit-user-select':'none'
      'user-select':'none'
    $this.each -> this.onselectstart = -> return false
# jQuery plugin to enable text selection (x-browser).
$.fn.enableSelection = ->
  @each ->
    $this = $(this)
    $this.attr 'unselectable', ''
    $this.css
      '-moz-user-select': ''
      '-webkit-user-select': ''
      'user-select': ''
    $this.each -> this.onselectstart = null


$.extend REPLIT,
  split_ratio: .5
  # Initialize the DOM (Runs before JSRPEL's load)
  InitDOM: ->
    @$doc_elem = $('html')
    # The div showing the current selected language.
    @$current_lang_name = $('#language')
    # The main container holding the editor and console.
    @$container = $('#content')
    # The container holding the editor widget and related elements.
    @$editorContainer = $('#editor')
    # The container holding the console widget and related elements.
    @$consoleContainer = $('#console')
    # An object holding all the resizer elements.
    @$resizer =
      l: $('#resize-left')
      c: $('#resize-center')
      r: $('#resize-right')
    # The loading throbber.
    @$throbber = $('#throbber')
    # An object holding unhider elements.
    @$unhider = 
      editor: $('#unhide-right')
      console: $('#unhide-left')
    
    @$run = $('#editor-run')
    @$editorContainer.hover =>
      @$run.fadeToggle 'fast'
    @$editorContainer.mousemove =>
      @$run.fadeIn 'fast'
    @$editorContainer.keydown =>
      @$run.fadeOut 'fast'
    # Initialaize the column resizer.
    @InitResizer()
    # Attatch unhiders functionality.
    @InitUnhider()
    # Fire the onresize method to do initial resizing
    @OnResize()
    # When the window call the containers resizer.
    $(window).bind 'resize',-> REPLIT.OnResize()

  # Attatches the resizers behaviors.
  InitResizer: ->
    $body = $('body')
    # For all resizers discard right clicks,
    # disable text selection on drag start.
    for n, $elem of @$resizer
      $elem.mousedown (e) ->
        if e.button != 0
          e.stopImmediatePropagation() 
        else
          $body.disableSelection()
    
    # When stopping the drag unbind the mousemove handlers and enable selection.
    resizer_lr_release = ->
      $body.enableSelection()
      $body.unbind 'mousemove.resizer'
      
    # On start drag bind the mousemove functionality for right/left resizers.
    @$resizer.l.mousedown (e) =>
      $body.bind 'mousemove.resizer', (e) =>
        # The horizontal mouse position is simply half of the content_padding.
        # Subtract half of the resizer_width for better percesion.
        CONTENT_PADDING = ((e.pageX - (RESIZER_WIDTH / 2)) * 2)
        @OnResize()
    @$resizer.r.mousedown (e) =>
      $body.bind 'mousemove.resizer', (e) =>
        # The mouse is on the right of the container, subtracting the horizontal
        # position from the page width to get the right number.
        CONTENT_PADDING = ($body.width() - e.pageX - (RESIZER_WIDTH / 2)) * 2
        @OnResize()
        
    # Bind the release on mouseup for right/left resizers.
    @$resizer.l.mouseup resizer_lr_release
    @$resizer.r.mouseup resizer_lr_release
    
    # When stopping the drag or when the editor/console snaps into hiding,
    # unbind the mousemove event for the container.
    resizer_c_release = =>
      @$container.enableSelection()
      @$container.unbind 'mousemove.resizer'
    
    # When start drag for the center resizer bind the resize logic.
    @$resizer.c.mousedown (e) =>
      @$container.bind 'mousemove.resizer', (e) =>
        # Get the mousposition relative to the container.
        left = e.pageX - (CONTENT_PADDING / 2) + (RESIZER_WIDTH / 2)
        # The ratio of the editor-to-console is the relative mouse position
        # divided by the width of the container.
        @split_ratio = left / @$container.width()
        # If the smaller split ratio as small as 0.5% then we must hide the element.
        if @split_ratio > 0.95
          @split_ratio = 1
          # Stop the resize drag.
          resizer_c_release()
        else if @split_ratio < 0.05
          @split_ratio = 0
          # Stop the resize drag.
          resizer_c_release()
        # Run the window resize handler to recalculate everything.
        @OnResize()
    
    # Release when:
    @$resizer.c.mouseup resizer_c_release
    @$container.mouseup resizer_c_release
    @$container.mouseleave resizer_c_release
  
  InitUnhider: ->
    # TODO(amasad): When typing and moving mouse the icon will start blinking,
    # maybe implement debounce.
    
    # When the mouse move on the page and an element is hidden show the
    # appropriate unhider.
    $('body').mousemove =>
      if @split_ratio == CONSOLE_HIDDEN
        @$unhider.console.fadeIn 'fast'
      else if @split_ratio == EDITOR_HIDDEN
        @$unhider.editor.fadeIn 'fast'
    # When typing start on an element make sure the unhider is hidden.
    @$container.keydown =>
      if @split_ratio == CONSOLE_HIDDEN
        @$unhider.console.fadeOut 'fast'
      else if @split_ratio == EDITOR_HIDDEN
        @$unhider.editor.fadeOut 'fast'
    
    # Handler for when clicking an unhider.
    click_helper = ($elem, $elemtoShow) =>
      $elem.click (e) =>
        # Hide the unhider.
        $elem.hide()
        # Get the split ratio to the default split.
        @split_ratio = DEFAULT_SPLIT
        # Show the hidden element.
        $elemtoShow.show()
        # Show the center resizer.
        @$resizer.c.show()
        # Recalculate all sizes.
        @OnResize()
        
    click_helper @$unhider.editor, @$editorContainer
    click_helper @$unhider.console, @$consoleContainer
      
  # Resize containers on each window resize, split ratio change or 
  # content padding change.
  OnResize: ->
    # Calculate container width.
    width = document.documentElement.clientWidth - CONTENT_PADDING
    height = document.documentElement.clientHeight - HEADER_HEIGHT - FOOTER_HEIGHT
    editor_width = (@split_ratio * width) -  (RESIZER_WIDTH * 1.5)
    console_width = ((1 - @split_ratio) * width) - (RESIZER_WIDTH * 1.5)
    
    # The center resizer is placed to the left of the editor.
    @$resizer.c.css 'left', editor_width + RESIZER_WIDTH
    # Do the actual resizing.
    @$container.css
      width: width
      height: height
    @$editorContainer.css
      width: editor_width
      height: height
    @$consoleContainer.css
      width: console_width
      height: height
    
    # Check if console/editor was meant to be hidden.
    if @split_ratio == CONSOLE_HIDDEN
      @$consoleContainer.hide()
      @$resizer.c.hide()
      @$unhider.console.show()
    else if @split_ratio == EDITOR_HIDDEN
      @$editorContainer.hide()
      @$resizer.c.hide()
      @$unhider.editor.show()
    # Call to resize environment if the app has already initialized.
    REPLIT.EnvResize() if @inited

  # Calculates editor and console dimensions according to their parents and
  # neighboring elements (if any).
  EnvResize: ->
    # Calculate paddings if any.
    console_hpadding = @$console.innerWidth() - @$console.width()
    console_vpadding = @$console.innerHeight() - @$console.height()
    editor_hpadding = @$editor.innerWidth() - @$editor.width()
    editor_vpadding = @$editor.innerHeight() - @$editor.height()
    # Resize the console/editor widgets.
    @$console.css 'width', @$consoleContainer.width() - console_hpadding
    @$console.css 'height', @$consoleContainer.height() - console_vpadding
    @$editor.css 'width', @$editorContainer.innerWidth() - editor_hpadding
    @$editor.css 'height', @$editorContainer.innerHeight() - editor_vpadding
    
    # Call to Ace editor resize.
    @editor.resize()


  InjectSocial: ->
    # Some of this is fucking with Ace's loading so we dynamically inject the
    # social shit. Facebook doesn't like being injected so it gets a special
    # treatment.
    # TODO(amasad): Use the actual async scripts provided by Google/FB/Twitter.
    #               These are just design no-ops.
    html = """
    <!-- Google+ -->
    <div class="social_button" type="google">
      <script type="text/javascript" src="https://apis.google.com/js/plusone.js"></script>
      <g:plusone size="medium"></g:plusone>
    </div>
    <!-- Twitter -->
    <div class="social_button" type="twitter">
      <a href="http://twitter.com/share" class="twitter-share-button" data-text="Testing out the twitter button." data-url="http://localhost" data-count="horizontal" data-via="Localhost">Tweet</a><script type="text/javascript" src="http://platform.twitter.com/widgets.js"></script>
    </div>
    <!-- Hacker News -->
    <a href="http://news.ycombinator.com/submitlink?u=&amp;t=http://localhost/" class="social_button">
      <img src="images/hnlike.png" />
    </a>
    """
    $('#social-buttons-container').append(html)

$ ->
  REPLIT.$this.bind 'language_loading', ->
    REPLIT.$throbber.show()
  
  REPLIT.$this.bind 'language_loaded', (e, lang_name) ->
    REPLIT.$throbber.hide()
    REPLIT.$current_lang_name.text lang_name
  
  REPLIT.InitDOM()
  REPLIT.OnResize()
    