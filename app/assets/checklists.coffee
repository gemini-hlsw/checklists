window.Checklists = Ember.Application.create
  ready: () ->
    router = this.get('router')
    $.ajax
      url: '/about'
      success: (data) ->
        Checklists.about.set('description', data)
    if Modernizr.localstorage
      if not localStorage.theme?
        localStorage.theme = 'dark'
      router.get('preferencesController').set('theme', localStorage.theme)

Ember.LOG_BINDINGS = false

p = (msg) ->
  console.log msg

Checklists = window.Checklists
###
# Utility functions
###
Checklists.urlDateFormat = 'YYYYMMDD'
Checklists.longDateFormat = 'dddd, MMMM Do YYYY'
Checklists.calendarDateFormat = 'DD/MM/YYYY'

###
# Top level controller and view
###
Checklists.ApplicationController = Ember.Controller.extend()

Checklists.ApplicationView = Ember.View.extend
  templateName: 'application'

###
# Data used on the about box
###
Checklists.about = Ember.Object.create
  description: ''

###
# View encapsulating a field inside a contenteditable element
###
Checklists.ContentEditable = Ember.View.extend
  value: ''
  tagName: "div"
  contenteditable: "true"
  attributeBindings: ["contenteditable"]
  valueChanged: ( ->
    this._updateElementValue()
  ).observes('value')

  didInsertElement: ->
    this._updateElementValue()

  _updateElementValue: ->
    this.$().html(@get('value'))

  _elementValueDidChange: () ->
    @set('value', this.$().html())

###
# View of a resizable text area
###
Checklists.ResizableTextArea = Ember.TextArea.extend
  didInsertElement: ->
    this._super()
    this.$().autosize
      append: "\n"

###
# Model for the site with the server date
###
Checklists.Site = Ember.Object.extend
  site: ''
  name: ''

# Displays an overlay with a spinning wheel
Checklists.OverlayView = Ember.View.extend
  templateName: 'overlay'
  didInsertElement: ->
    this._super()
    this.$('.overlay').spin('large', 'white')
  willDestroyElement: ->
    this.$('.overlay').spin(false)

# Displays an overlay with a spinning wheel and a message
Checklists.SavingOverlayView = Ember.View.extend
  templateName: 'saving_overlay'
  didInsertElement: ->
    this._super()
    this.$('.overlay').spin('large', 'white')
  willDestroyElement: ->
    this.$('.overlay').spin(false)

Checklists.SitesRepository = Ember.Object.create
  sites: []
  createFromJson: (json) ->
    Checklists.Site.create
      site: json.site
      name: json.name
  findAll: ->
    self = this
    if self.sites.length is 0
      $.ajax
        url: '/api/v1.0/sites'
        success: (response) ->
          response.forEach (site) =>
            self.sites.pushObject(Checklists.SitesRepository.createFromJson(site))
    self.sites

Checklists.CheckValues = ['', 'done', 'not done', 'NA', 'Ok', 'pending', 'not Ok']

Checklists.DatePicker = Ember.View.extend
  templateName: 'datepicker'
  classNames: ['input-prepend date datepicker']
  tagName: 'div'
  attributeBindings: ['date', 'data-date', 'inputFormat', 'format']
  format:'dd/mm/yyyy'
  inputFormat: Checklists.urlDateFormat
  'data-date': ''
  _dateChanged: (e, self) =>
    key = Checklists.get('router').get('checklistController').get('key')
    date = moment(e.date).format(self.get('inputFormat'))
    Checklists.get('router').send('goToDay', {key: key, date: date})
  _toDate: ->
    moment(@get('date'), @get('inputFormat')).toDate()
  formattedDate: ( ->
      @_toDate()
    ).property('date')
  didInsertElement: ->
    $('.date').datepicker
      format: @get('format')
      autoclose: true
      todayHighlight: true
      todayBtn: 'linked'
    $('.date').datepicker('update', @_toDate()).on 'changeDate', (e) =>
        @_dateChanged(e, this)

###
# View of a resizable text area
###
Checklists.TemplateField = Ember.TextField.extend
  didInsertElement: ->
    if @get('context.newCheck')
      this.$().focus()

###
# View of a Select2 box with tags
###
Checklists.Select2Tags = Ember.View.extend
  tagName: 'input'
  classNames: ['ember-tags']
  defaultTemplate: ''

  attributeBindings: ['type', 'tabindex', 'placeholder', 'tags', 'value', 'dropdownCssClass'],
  type: 'hidden'
  tags: []
  values: null
  value: null
  dropdownCssClass: ''
  containerCssClass: ''
  tagsUpdater: (->
    this.$().select2({tags: @get('tags')})
  ).observes('tags')
  valuesUpdater: (->
    data = []
    data.push({id: i, text:i}) for i in @get('values') when i.trim().length > 0
    val = this.$().select2("val")
    if val.length isnt data.length
      this.$().select2({tags: @get('tags'), initSelection: @_initSelection}).select2("val", data)
  ).observes('values')
  _initSelection: (e, cb) ->
    if Ember.View.views[e.context.id]?
      view = Ember.View.views[e.context.id]
      values = if view.get('values')? then view.get('values') else []
      data = []
      data.push({id: i, text:i}) for i in values when i.trim().length > 0
      cb(data)
  _change: (event, ref) ->
    Ember.View.views[event.target.id].set('values', event.val) if Ember.View.views[event.target.id]
  didInsertElement: ->
    data = []
    (data.push({id: i, text:i}) for i in @get('values') when i.trim().length > 0) if @get('values')?
    tags = if @get('tags')? then @get('tags') else []
    this.$().select2({tags: tags, containerCssClass: @get('containerCssClass'), dropdownCssClass: @get('dropdownCssClass'), allowClear: true, initSelection: @_initSelection}).select2("val", data).on('change', @_change)

Checklists.Select2 = Ember.View.extend
  tagName: 'input'
  classNames: ['ember-tags']
  defaultTemplate: ''

  attributeBindings: ['type', 'tabindex', 'placeholder', 'value', 'dropdownCssClass'],
  type: 'hidden'
  options: null
  value: null
  dropdownCssClass: ''
  containerCssClass: ''
  valuesUpdater: (->
    data = []
    data.push({id: i, text:i}) for i,k in @get('options') when i.trim().length > 0
    val = this.$().select2("val")
    if val.length isnt data.length
      this.$().select2({data: data, initSelection: @_initSelection}).select2("val", data)
  ).observes('values')

  _initSelection: (e, cb) ->
    if Ember.View.views[e.context.id]?
      view = Ember.View.views[e.context.id]
      data = if view.get('value')? then {id: view.get('value'), text: view.get('value')} else null
      cb(data)
  _change: (event, ref) ->
    Ember.View.views[event.target.id].set('value', event.val) if Ember.View.views[event.target.id]
  didInsertElement: ->
    data = []
    (data.push({id: i, text:i}) for i, k in @get('options') when i.trim().length > 0) if @get('options')?
    this.$().select2({data: data, containerCssClass: @get('containerCssClass'), dropdownCssClass: @get('dropdownCssClass'), allowClear: true, initSelection:@_initSelection}).on('change', @_change)

###
# View of a resizable text area
###
Checklists.Select2Checks = Ember.View.extend
  tagName: 'input'
  classNames: ['ember-tags']
  defaultTemplate: ''

  attributeBindings: ['type', 'tabindex', 'placeholder', 'value', 'dropdownCssClass'],
  type: 'hidden'
  options: null
  value: null
  dropdownCssClass: ''
  containerCssClass: ''
  valuesUpdater: (->
    data = []
    data.push({id: i, text:i}) for i,k in @get('options') when i.trim().length > 0
    val = this.$().select2("val")
    if val.length isnt data.length
      this.$().select2({data: data, initSelection: @_initSelection}).select2("val", data)
  ).observes('values')
  _format: (state) ->
    console.log(state)
    "<input type='checkbox'>&nbsp;" + state.text;
  _initSelection: (e, cb) ->
    if Ember.View.views[e.context.id]?
      view = Ember.View.views[e.context.id]
      data = if view.get('value')? then {id: view.get('value'), text: view.get('value')} else null
      cb(data)
  _change: (event, ref) ->
    Ember.View.views[event.target.id].set('value', event.val) if Ember.View.views[event.target.id]
  didInsertElement: ->
    data = []
    (data.push({id: i, text:i}) for i, k in @get('options') when i.trim().length > 0) if @get('options')?
    this.$().select2({data: data, multiple: true, closeOnSelect: true, formatResult: @_format, containerCssClass: @get('containerCssClass'), dropdownCssClass: @get('dropdownCssClass'), allowClear: true, initSelection:@_initSelection}).on('change', @_change)

Checklists.ChoicesCheckbox =  Ember.Checkbox.extend
  attributeBindings: ['disabled']

Checklists.TemplateCheckView = Ember.View.extend
  templateName: 'templatecheck'
  choicesDisplayed: false
  choicesView: null
  showChoices: ->
    @set('choicesDisplayed', not @get('choicesDisplayed'))
    if @get('choicesDisplayed')
      view = Checklists.ChoicesListView.create()
      view.set('context', @get('context'))
      @set('choicesView', view)
    else
      @set('choicesView', null)

###
# View and controller to edit a template
###
Checklists.TemplateView = Ember.View.extend
  templateName: 'edit_template'
  didInsertElement: ->
    Mousetrap.bind ['ctrl+s', 'command+s'], ->
      Checklists.get('router').send('saveTemplate')
      false
  willDestroyElement: ->
    Mousetrap.unbind ['ctrl+s', 'command+s']
  toggleGroup: (event) ->
    event.context.set('collapsed', not event.context.get('collapsed'))
  addGroup:  ->
    confirm = (result) =>
      if result?
        @get('controller.content').addGroup(result)
    bootbox.prompt("Enter the group name:", "Cancel", "OK", confirm, "New Group")
  addCheck: (event) ->
    @get('controller.content').addCheck(event.context.get('position'))
    # Open the group
    event.context.set('collapsed', true)
  deleteCheck: (event) ->
    @get('controller.content').deleteCheck(event.contexts[0].get('position'), event.contexts[1].get('position'))
  moveUp: (event) ->
    @get('controller.content').moveUp(event.contexts[0].get('position'), event.contexts[1].get('position'))
  moveDown: (event) ->
    @get('controller.content').moveDown(event.contexts[0].get('position'), event.contexts[1].get('position'))
  moveGroupUp: (event) ->
    @get('controller.content').moveGroupUp(event.context.get('position'))
  moveGroupDown: (event) ->
    @get('controller.content').moveGroupDown(event.context.get('position'))
  deleteGroup: (event) ->
    @get('controller.content').removeGroup(event.context.get('position'))

Checklists.TemplateController = Ember.ObjectController.extend
  content: null
  choicesPrevious: Ember.A([])
  choicesChange: ( ->
    previous = @get('choicesPrevious')
    if (previous.length > 0)
      @_updatedChoices()
    @set('choicesPrevious', @get('choices'))
  ).observes('content.choices.@each')
  _updatedChoices: () ->
    previous = @get('choicesPrevious')
    current = @get('content.choices')
    # This is n**2 but let's assume we won't have very long lists of choices
    if (previous.length > current.length)
      removed = previous.filter (i) ->
        not current.contains(i)
      @get('content').removeChoice(removed[0])
      # This should be in the view layer
      $.gritter.add
        title: "'#{removed[0]}' removed!"
        text: "The status choice '#{removed[0]}' has been removed from each of the checks"
    if (previous.length < current.length)
      added = current.filter (i) ->
        not previous.contains(i)
      @get('content').addChoice(added[0])
      # This should be in the view layer
      $.gritter.add
        title: "'#{added[0]}' added!"
        text: "The status choice '#{added[0]}' has not been added to existing checks but you can enable it"

Checklists.Template = Ember.Object.extend
  key: ''
  name: ''
  groups: []
  choices: []
  isLoaded: false
  isSaved: true
  colPos: 0
  rowPos: 0
  saveOnClose: false
  fromEmail: ''
  toEmail: []
  needsOverlay: ( ->
    not @get('isLoaded') or not @get('isSaved')
  ).property('isLoaded', 'isSaved')
  removeChoice: (choice) ->
    @get('groups').forEach (g) ->
      g.get('checks').forEach (c) ->
        c.get('choices').removeObjects(c.get('choices').filterProperty('name', choice))
  addChoice: (choice) ->
    @get('groups').forEach (g) ->
      g.get('checks').forEach (c) ->
        c.get('choices').pushObject({name: choice, selected: false})
  findGroup: (groupPosition) ->
    @get('groups').find (g) ->
      g.get('position') is groupPosition
  addGroup: (name) ->
    group = Checklists.TemplateGroup.create
      name: name
      title: name
      checks: Ember.A()
    @get('groups').insertAt(0, group)
    @normalizeGroupPositions()
  removeGroup: (name) ->
    g = @findGroup(name)
    @get('groups').removeObject(g)
    @normalizeGroupPositions()
  addCheck: (name) ->
    g = @findGroup(name)
    nc = Checklists.TemplateCheck.create
      title: ''
      position: g.get('checks').length
      newCheck: true
      choices: Ember.A(Checklists.TemplateRepository.choiceFromJson({name: c, selected: true} ) for c in @get('choices'))
    g.get('checks').pushObject(nc)
  moveUp: (position, groupPosition) ->
    if position > 0
      g = @findGroup(groupPosition)
      checks = g.get('checks')
      r = checks[position - 1]
      c = checks[position]
      checks.replace(position - 1, 2, [c, r])
      g.normalizeCheckPositions()
  moveDown: (position, groupPosition) ->
    g = @findGroup(groupPosition)
    checks = g.get('checks')
    if position < checks.length - 1
      r = checks[position + 1]
      c = checks[position]
      checks.replace(position, 2, [r, c])
      g.normalizeCheckPositions()
  moveGroupUp: (position) ->
    if position > 0
      groups = @get('groups')
      r = groups[position - 1]
      c = groups[position]
      groups.replace(position - 1, 2, [c, r])
      @normalizeGroupPositions()
  moveGroupDown: (position) ->
    groups = @get('groups')
    if position < groups.length - 1
      r = groups[position + 1]
      c = groups[position]
      groups.replace(position, 2, [r, c])
      @normalizeGroupPositions()
  deleteCheck: (position, groupPosition) ->
    g = @findGroup(groupPosition)
    c = g.get('checks').find (e)->
      e.get('position') is position
    g.get('checks').removeObject(c)
    g.normalizeCheckPositions()
  normalizeGroupPositions: ->
    e.set('position', i) for e, i in @get('groups')

Checklists.ChoicesListView = Ember.View.extend
  templateName: 'choiceslist'
  checkAll: ->
    @get('context').checkAll()
  checkNone: ->
    @get('context').checkNone()

Checklists.TemplateCheckChoice = Ember.Object.extend
  name: ''
  selected: false

Checklists.TemplateCheck = Ember.Object.extend
  title: ''
  position: 0
  choices: Ember.A()
  freeText: false
  checkAll: ->
    @get('choices').forEach (i) ->
      i.set('selected', true)
  checkNone: ->
    @get('choices').forEach (i) ->
      i.set('selected', false)

Checklists.TemplateGroup = Ember.Object.extend
  name: ''
  title: ''
  checks: Ember.A()
  position: 0
  collapsed: false # Move to controller
  normalizeCheckPositions: ->
    e.set('position', i) for e, i in @get('checks')

Checklists.TemplateSettings = Ember.Object.extend
  engineers: null
  technicians: null

Checklists.TemplateSettingsController = Ember.ObjectController.extend
  content: null

Checklists.TemplatesView = Ember.View.extend
  columnCount: 2
  templateName: 'templates'
  rows: ( ->
    r = [0..@get('context.content').length/2]
    r.map (i) =>
      @get('context.content').filterProperty('rowPos', i)
  ).property('context.content.@each')

Checklists.TemplatesController = Ember.ArrayController.extend
  isLoaded: ( ->
    @get('content').length > 0
  ).property('content.@each')

Checklists.TemplateRepository = Ember.Object.create
  templates: Ember.A([])
  findSettings: (key) ->
    settings = Checklists.TemplateSettings.create
      engineers: Ember.A()
      technicians: Ember.A()
    $.ajax
      url: "/api/v1.0/templates/#{key}/settings",
      success: (response) =>
        settings.setProperties response
    settings
  choiceFromJson: (json) ->
    Checklists.TemplateCheckChoice.create
      name: json.name
      selected: json.selected
  checkFromJson: (json, index) ->
    Checklists.TemplateCheck.create
      title: json.title
      position: json.position
      freeText: json.freeText
      choices: Ember.A(Checklists.TemplateRepository.choiceFromJson(c) for c in json.choices)
  groupFromJson: (json) ->
    group = Checklists.TemplateGroup.create
      name: ''
      title: ''
      checks: Ember.A()
    group.setProperties(json)
    checks = Ember.A(Checklists.TemplateRepository.checkFromJson(c, i) for c, i in json.checks)
    group.set('checks', checks)
    group.normalizeCheckPositions()
    group
  findTemplate: (template) ->
    key = template.get('key')
    if @templates[key]?
      @templates[key]
    else
      template = Checklists.Template.create
        key: key
        name: template.get('name')
        isSaved: true
        colPos: 0
        rowPos: 0
      $.ajax
        url: "/api/v1.0/templates/#{key}",
        success: (response) =>
          template.setProperties response
          groups = Ember.A()
          groups.addObject(Checklists.TemplateRepository.groupFromJson(g)) for g in response.groups
          template.set('groups', groups)
          template.set('isLoaded', true)
          template.normalizeGroupPositions()
      @templates[key] = template
      template
  findAll: ->
    $.ajax
      url: "/api/v1.0/templates",
      success: (response) =>
        response.forEach (t) =>
          template = Checklists.Template.create
            isSaved: true
          template.setProperties t
          groups = Ember.A()
          groups.addObject(Checklists.TemplateRepository.groupFromJson(g)) for g in t.groups
          template.set('groups', groups)
          template.set('isLoaded', true)
          template.normalizeGroupPositions()
          previous = @templates.findProperty('key', t.key)
          if previous
            @templates.replace(@templates.indexOf(previous), 1, [template])
          else
            @templates.pushObject(template)
        @templates.set('isLoaded', true)
    @templates
  saveTemplate: (template) ->
    template.set('isSaved', false)
    key = template.get('key')
    $.ajax
      url: "/api/v1.0/templates/#{key}",
      type: 'PUT'
      contentType: 'application/json'
      data: JSON.stringify(template)
      success: (response) =>
        template.set('isSaved', true)
        t = @templates.findProperty('key', key)
        @templates.replace(@templates.indexOf(t), 1, [template])
        # Clean the cache so new checklists use the new template
        Checklists.ChecklistRepository.cleanCache()
  createNewTemplate: (key, name, callback) ->
    $.ajax
      url: "/api/v1.0/templates/#{key}",
      type: 'POST'
      contentType: 'application/json'
      data: JSON.stringify({key: key, name: name})
      success: (response) =>
        template = Checklists.Template.create
          isSaved: true
        template.setProperties(response)
        @templates.pushObject(template)
        callback() if callback?

switchLink = (title, name, postfix) ->
  $("link[name=#{title}]").each ->
    this.href = "3/assets/stylesheets/#{title}-#{name}#{postfix}.css"

Checklists.switchStyle = (name)->
  switchLink("bootstrap", name, ".min")
  switchLink("checklist", name, "")
  if Modernizr.localstorage
    localStorage.theme = name

$.validator.addMethod(
  "regex",
  (value, element, regexp) ->
    re = new RegExp(regexp)
    this.optional(element) or re.test(value)
  "Please check your input.")

###
# View and controller for the toolbar
###
Checklists.ToolbarView = Ember.View.extend
  templateName: 'toolbar'
  voidAction: ->
    false
  addChecklist: ->
    this.$('#add-checklist-modal').modal({})
    val = $('#template-create').validate
      errorClass:'error'
      validClass:'success'
      errorElement:'span'
      highlight: (element, errorClass, validClass) ->
        $(element).parents('.control-group').addClass(errorClass).removeClass(validClass)
      unhighlight: (element, errorClass, validClass) ->
        $(element).parents('.error').removeClass(errorClass).addClass(validClass)
      messages:
        name: 'Name is required'
        key:
          required: 'Key is required'
          regex: 'Key must be all capitals, no spaces'
      rules:
        key:
          required: true
          regex: '^[A-Z][A-Z0-9]*$'
          remote:
            url: '/api/v1.0/validation/templatekey'
            type: 'POST'
        name:
          required: true
      errorPlacement: (error, element) =>
        element.closest('.control-group').find('.help-block').html(error.text())
      success: (label) =>
        true
      this.$('#add-checklist-submit').on 'click', =>
        if val.form()
          val.resetForm()
          this.$('#add-checklist-submit').button('loading')
          Checklists.TemplateRepository.createNewTemplate  this.$('#template-key').val(), this.$('#template-name').val(), =>
            this.$('input').val('').removeClass('error').removeClass('success')
            this.$('#add-checklist-submit').button('reset')
            this.$('#add-checklist-modal').modal('hide')
  showReport: (e) ->
    context = Ember.Object.create
      key: e.contexts[0]
      year: e.contexts[1]
      month: moment.months.indexOf(e.contexts[2]) + 1
    Checklists.get('router').send('moveToMonthReport', context)
      
Checklists.ToolbarController = Ember.Controller.extend
  state: ''
  inReport: ( ->
    @get('state') is 'report'
  ).property('state')
  inChecklist: ( ->
    @get('state') is 'checklist'
  ).property('state')
  inHome: ( ->
    @get('state') is 'home'
  ).property('state')
  showReports: ( ->
    @get('inChecklist') or @get('inReport')
  ).property('inChecklist', 'inReport')
  availableReportsBinding: 'Checklists.router.reportsMenuController.content'
  checklistDateBinding: 'Checklists.router.checklistController.date'
  checklistKeyBinding: 'Checklists.router.checklistController.key'

Checklists.ReportsMenuController =  Ember.ObjectController.extend
  content: ''

###
# View and controller for showing reports
###
Checklists.ReportsView = Ember.View.extend
  templateName: 'reports'
Checklists.ReportsController = Ember.ObjectController.extend
  content: null

Checklists.DailySummaryRowView = Ember.View.extend
  templateName: 'daily_summary_row'
  didInsertElement: ->
    Ember.run ->
      this.$('.collapse').on 'hide', ->
        icon = $('<i class="icon-chevron-right">')
        $(this).parent('td').find('.details-trigger').text("Show details ").append(icon)
      this.$('.collapse').on 'show', ->
        icon = $('<i class="icon-chevron-down">')
        $(this).parent('td').find('.details-trigger').text("Hide details ").append(icon)
  showDetails: (event) ->
    id = event.context.get('detailsIdHash')
    Ember.run ->
      this.$(id).collapse('toggle')

Checklists.DaySummary = Ember.Object.extend
  closed: false
  status: ''
  checklist: ''
  date: ''
  key: ''
  day: (->
    moment(@get('date'), Checklists.urlDateFormat).date()
  ).property('date')
  notClosed: (->
    not @get('closed')
  ).property('closed')
  summaryText: (->
    status = @get('status')
    [" #{p}: #{status[p]}" for p of status].join(', ')
  ).property('@each.status')
  detailsId: ( ->
    date = @get('date')
    "details-#{date}"
  ).property('date')
  detailsIdHash: ( ->
    date = @get('date')
    "#details-#{date}"
  ).property('date')

Checklists.MonthReport = Ember.ArrayController.extend
  isLoaded: false
  key: ''
  name: ''
  from: ''
  to: ''
  year: 0
  month: 0
  monthName: (->
    c = moment.months[@get('month') - 1]
  ).property('month')
  containsReports: (->
    @get('content').length > 0
  ).property('@each.content')
  content: Ember.A()

Checklists.ReportRepository = Ember.Object.create
  loadMenuSet: (key) ->
    reports = Ember.Object.create
      years: Ember.A()
    $.ajax
      url: "/api/v1.0/reports/months/#{key}"
      success: (data) ->
        reports.set('years', Ember.A(data))
    reports
  buildSummary: (json) ->
    d = Checklists.DaySummary.create()
    d.setProperties(json)
    d.set('checklist', Checklists.ChecklistRepository.checklistFillJson(Checklists.ChecklistRepository.newChecklist(json.checklist.key, json.date), json.checklist))
    d
  loadReport: (key, year, month) ->
    report = Checklists.MonthReport.create
      isLoaded: false
      key: key
      name: name
      year: year
      month: month
      summary: Ember.A()
    $.ajax
      url: "/api/v1.0/checklist/report/#{key}/#{year}/#{month}",
      success: (response) =>
        report.setProperties(response)
        report.set('isLoaded', true)
        report.set('content', Checklists.ReportRepository.buildSummary(s, response) for s in response.summary)
    report

###
 Store local preferences
###
Checklists.PreferencesController =  Ember.Controller.extend
  theme: 'dark'
  clearIcon: ( ->
    if @get('theme') is 'clear' then 'icon-ok' else 'icon-'
  ).property('theme')
  darkIcon: ( ->
    if @get('theme') is 'dark' then 'icon-ok' else 'icon-'
  ).property('theme')
  observer: ( ->
    Checklists.switchStyle(@get('theme'))
  ).observes('theme')

Checklists.ThemesMenuView = Ember.View.extend
  templateName: 'theme_menu'
  tagName: 'li'
  switchToClear: ->
    @set('controller.theme', 'clear')
  switchToDark: ->
    @set('controller.theme', 'dark')

###
# View and controller for a checklist
###
Checklists.ChecklistView = Ember.View.extend
  templateName: 'checklist'
  settingsControllerBinding: 'Checklists.router.templateSettingsController'
  toggleGroup: (event) ->
    event.context.set('collapsed', not event.context.get('collapsed'))
  closeChecklist: ->
    bootbox.confirm "Are you sure you want to close? This action is irreversible", (result) ->
      if result
        Ember.run ->
          Checklists.get('router').send('closeChecklist')
  didInsertElement: ->
    Mousetrap.bind ['ctrl+s', 'command+s'], ->
      Checklists.get('router').send('saveChecklist')
      false
  willDestroyElement: ->
    Mousetrap.unbind ['ctrl+s', 'command+s']

Checklists.ChecklistController = Ember.ObjectController.extend
  content: null

Checklists.Checklist = Ember.ObjectController.extend
  key: ''
  name: ''
  date: ''
  closed: false
  groups: []
  isLoaded: false
  isSaved: true
  engineers: []
  technicians: []
  needsOverlay: ( ->
    not @get('isLoaded') or not @get('isSaved')
  ).property('isLoaded', 'isSaved')
  canDisplay: ( ->
    @get('isLoaded') and @get('isSaved')
  ).property('isLoaded', 'isSaved')
  longFormattedDate: ( ->
    d = moment(@get('date'), Checklists.urlDateFormat)
    if d? then d.format(Checklists.longDateFormat) else ''
  ).property('date')
  calendarFormattedDate: ( ->
    d = moment(@get('date'), Checklists.urlDateFormat)
    if d? then d.format(Checklists.calendarDateFormat) else ''
  ).property('date')

Checklists.Check = Ember.Object.extend
  description: ''
  status: ''
  comment: ''
  freeText: false

Checklists.ChecksGroup = Ember.Object.extend
  name: ''
  title: ''
  checks: ''
  collapsed: false # Move to controller

Checklists.ChecklistRepository = Ember.Object.create
  checklistsCache: {}
  cleanCache: ->
    @set('checklistsCache', {})
  checkFromJson: (json) ->
    check = Checklists.Check.create()
    check.setProperties(json)
  checklistGroupFromJson: (json) ->
    group = Checklists.ChecksGroup.create
      name: ''
      title: ''
      checks: Ember.A()
    group.setProperties(json)
    checks = Ember.A()
    checks.addObject(Checklists.ChecklistRepository.checkFromJson(c)) for c in json.checks
    group.set('checks', checks)
  checklistFillJson: (checklist, json) ->
    checklist.setProperties(json)
    groups = Ember.A()
    groups.addObject(Checklists.ChecklistRepository.checklistGroupFromJson(g)) for g in json.groups
    checklist.set('groups', groups)
    checklist.set('isLoaded', true)
    checklist
  newChecklist: (key, date) ->
    Checklists.Checklist.create
      key: key
      name: ''
      date: date
      closed: false
      groups: []
  findOne: (key, date) ->
    if @get('checklistsCache')["#{key}-#{date}"]?
      @get('checklistsCache')["#{key}-#{date}"]
    else
      checklist = @newChecklist(key, date)
      @get('checklistsCache')["#{key}-#{date}"] = checklist
      $.ajax
        url: "/api/v1.0/checklist/#{key}/#{date}",
        success: (response) =>
          @checklistFillJson(checklist, response)
      checklist
  saveChecklist: (checklist) ->
    checklist.set('isSaved', false)
    $.ajax
      url: "/api/v1.0/checklist/#{checklist.key}/#{checklist.date}",
      type: 'POST'
      contentType: 'application/json'
      data: JSON.stringify(checklist)
      success: (response) =>
        checklist.setProperties(response)
        groups = Ember.A()
        groups.addObject(Checklists.ChecklistRepository.checklistGroupFromJson(g)) for g in response.groups
        checklist.set('groups', groups)
        @get('checklistsCache')["#{checklist.key}-#{checklist.date}"] = checklist
        checklist.set('isSaved', true)
      error: (response) =>
        msg = response.responseText.msg
        bootbox.alert("The checklist is already closed, cannot save!!")
        checklist.set('closed', true)
        checklist.set('isSaved', true)

Checklists.Router = Ember.Router.extend
  enableLogging: true
  setupReportsController: (key) ->
    this.get('reportsMenuController').set('content', Checklists.ReportRepository.loadMenuSet(key))
  root: Ember.Route.extend
    goToMain: Ember.Router.transitionTo('index')
    goToDay: Ember.Router.transitionTo('checklist')
    index: Ember.Route.extend
      route: '/'
      todayChecklist: (router, event) ->
        router.send('goToDay', {key: event.context.get('key'), date: moment().format(Checklists.urlDateFormat)})
      connectOutlets: (router) ->
        router.get('applicationController').connectOutlet('toolbar', 'toolbar')
        router.get('toolbarController').set('state', 'home')
        router.get('applicationController').connectOutlet('main', 'templates', Checklists.TemplateRepository.findAll())
    checklist: Ember.Route.extend
      route: '/:key/:date'
      saveChecklist: (router) ->
        checklist =  router.get('checklistController').get('content')
        Checklists.ChecklistRepository.saveChecklist(checklist)
      closeChecklist: (router) ->
        bootbox.hideAll()
        checklist =  router.get('checklistController').get('content')
        checklist.set('closed', true)
        Checklists.ChecklistRepository.saveChecklist(checklist)
      goToPrevious: (router, event) ->
        checklist =  router.get('checklistController').get('content')
        # current date
        previousDay = moment(checklist.get('date'), Checklists.urlDateFormat).subtract('days', 1)
        router.transitionTo('checklist', {key: checklist.get('key'), date: previousDay.format(Checklists.urlDateFormat)})
      goToNext: (router) ->
        checklist =  router.get('checklistController').get('content')
        # current date
        nextDay = moment(checklist.get('date'), Checklists.urlDateFormat).add('days', 1)
        router.transitionTo('checklist', {key: checklist.get('key'), date: nextDay.format(Checklists.urlDateFormat)})
      connectOutlets: (router, template) ->
        router.setupReportsController(template.key)
        checklist = Checklists.ChecklistRepository.findOne(template.key, template.date)

        router.get('toolbarController').set('state', 'checklist')
        router.get('toolbarController').set('key', template.key)
        router.get('applicationController').connectOutlet('toolbar', 'toolbar')
        router.get('applicationController').connectOutlet('main', 'checklist', checklist)

        router.get('templateSettingsController').set('content', Checklists.TemplateRepository.findSettings(template.key))
    editTemplate: Ember.Router.transitionTo('template')
    template: Ember.Route.extend
      route: '/:key/template'
      connectOutlets: (router, context) ->
        template = Checklists.TemplateRepository.findTemplate(context)
        router.get('toolbarController').set('state', 'template')
        router.get('templateController').set('content', template)
        router.get('applicationController').connectOutlet('main', 'template', template)
        router.get('applicationController').connectOutlet('toolbar', 'toolbar')
      saveTemplate: (router) ->
        template =  router.get('templateController').get('content')
        Checklists.TemplateRepository.saveTemplate(template)
      goBack: (router) ->
        key = router.get('templateController').get('content.key')
        checklist = router.get('checklistController').get('content')
        date = if checklist? then checklist.get('date') else moment().format(Checklists.urlDateFormat)
        router.transitionTo('checklist', {key: key, date: date})
      serialize: (router, context) ->
        key: context.get('key')
      deserialize: (router, urlParams) ->
        context = Ember.Object.create
          key: urlParams.key
          name: ''
        Checklists.TemplateRepository.findTemplate(context)
    moveToMonthReport: Ember.Router.transitionTo('report.monthReport')
    report: Ember.Route.extend
      route: '/report'
      monthReport: Ember.Route.extend
        route: '/:key/:year/:month'
        connectOutlets: (router, context) ->
          router.setupReportsController(context.get('key'))
          router.get('applicationController').connectOutlet('toolbar', 'toolbar')
          router.get('toolbarController').set('state', 'report')
          report = Checklists.ReportRepository.loadReport(context.get('key'), context.get('year'), context.get('month'))
          router.get('applicationController').connectOutlet('main', 'reports', report)
        serialize: (router, context) ->
          key: context.get('key')
          month: context.get('month')
          year: context.get('year')
        deserialize: (router, urlParams) ->
          context = Ember.Object.create
            key: urlParams.key
            month: urlParams.month
            year: urlParams.year

Checklists.initialize()