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
  date: ''

###
# View and controller to see the sites
###
Checklists.SitesView = Ember.View.extend
  templateName: 'sites'
Checklists.SitesController = Ember.ArrayController.extend
  content: []
  isLoaded: ( ->
    @get('content').length > 0
  ).property('@each.content')

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
      date: json.date
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
  classNames: ['input-append date']
  tagName: 'div'
  attributeBindings: ['data', 'data-date', 'inputFormat', 'format']
  format:'dd/mm/yyyy'
  inputFormat: Checklists.urlDateFormat
  'data-date': (->
    c = moment(@get('data'), @get('inputFormat'))
    c.format(Checklists.calendarFormattedDate)
  ).property('data'),
  dataBinding: null,
  didInsertElement: ->
    $('.date').datepicker
      format: @get('format')

###
# View and controller for the calendar
###
Checklists.SiteSwitchView = Ember.View.extend
  templateName: 'site_switch'
Checklists.SiteSwitchController = Ember.ObjectController.extend
  content: null

###
# View of a resizable text area
###
Checklists.TemplateField = Ember.TextField.extend
  attributeBindings: ['autofocus']
  autofocus: 'autofocus'

###
# View of a resizable text area
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

Checklists.TemplateCheckView = Ember.View.extend
  templateName: 'templatecheck'
  choicesDisplayed: false
  showChoices: ->
    @set('choicesDisplayed', not @get('choicesDisplayed'))

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
  addGroup:  ->
    confirm = (result) =>
      if result?
        @get('controller.content').addGroup(result)
    bootbox.prompt("Enter the group name:", "Cancel", "OK", confirm, "New Group")
  addCheck: (event) ->
    @get('controller.content').addCheck(event.context.get('position'))
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
      @get('content').updatedChoices(previous)
    @set('choicesPrevious', @get('choices'))
  ).observes('content.choices.@each')

Checklists.Template = Ember.Object.extend
  site: ''
  name: ''
  groups: []
  choices: []
  isLoaded: false
  isSaved: true
  needsOverlay: ( ->
    not @get('isLoaded') or not @get('isSaved')
  ).property('isLoaded', 'isSaved')
  updatedChoices: (previous) ->
    current = @get('choices')
    # This is n**2 but let's assume we won't have very long lists of choices
    if (previous.length > current.length)
      removed = previous.filter (i) ->
        not current.contains(i)
      @removeChoice(removed[0])
    if (previous.length < current.length)
      added = current.filter (i) ->
        not previous.contains(i)
      @addChoice(added[0])
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

Checklists.ChoicesList = Ember.View.extend
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
  normalizeCheckPositions: ->
    e.set('position', i) for e, i in @get('checks')

Checklists.TemplateSettings = Ember.Object.extend
  engineers: null
  technicians: null

Checklists.TemplateSettingsController = Ember.ObjectController.extend
  content: null

Checklists.TemplateRepository = Ember.Object.create
  templates: {}
  findSettings: (site) ->
    settings = Checklists.TemplateSettings.create
      engineers: Ember.A()
      technicians: Ember.A()
    $.ajax
      url: "/api/v1.0/templates/#{site}/settings",
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
  findTemplate: (site) ->
    key = site.get('site')
    if @templates[key]?
      @templates[key]
    else
      template = Checklists.Template.create
        site: key
        name: site.get('name')
        isSaved: true
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
  saveTemplate: (template) ->
    template.set('isSaved', false)
    $.ajax
      url: "/api/v1.0/templates/#{template.site}",
      type: 'POST'
      contentType: 'application/json'
      data: JSON.stringify(template)
      success: (response) =>
        template.set('isSaved', true)
        # Clean the cache so new checklists use the new template
        Checklists.ChecklistRepository.cleanCache()

switchLink = (title, name, postfix) ->
  $("link[name=#{title}]").each ->
    this.href = "/assets/stylesheets/#{title}-#{name}#{postfix}.css"

Checklists.switchStyle = (name)->
  switchLink("bootstrap", name, ".min")
  switchLink("checklist", name, "")
  if Modernizr.localstorage
    localStorage.theme = name

###
# View and controller for the toolbar
###
Checklists.ToolbarView = Ember.View.extend
  templateName: 'toolbar'
  voidAction: ->
    false
  showReport: (e) ->
    context = Ember.Object.create
      site: 'GS'
      year: e.contexts[0]
      month: moment.months.indexOf(e.contexts[1]) + 1
    Checklists.get('router').send('moveToMonthReport', context)
      
Checklists.ToolbarController = Ember.Controller.extend
  inChecklist: false
  inReport: false
  showReports: ( ->
    @get('inChecklist') or @get('inReport')
  ).property('inChecklist', 'inReport')
  availableReportsBinding: 'Checklists.router.reportsMenuController.content'

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
  site: ''
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
  site: ''
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
  loadMenuSet: (site) ->
    reports = Ember.Object.create
      years: Ember.A()
    $.ajax
      url: "/api/v1.0/reports/months/#{site}"
      success: (data) ->
        reports.set('years', Ember.A(data))
    reports
  buildSummary: (json) ->
    d = Checklists.DaySummary.create()
    d.setProperties(json)
    d.set('checklist', Checklists.ChecklistRepository.checklistFillJson(Checklists.ChecklistRepository.newChecklist(json.checklist.site, json.date), json.checklist))
    d
  loadReport: (site, year, month) ->
    report = Checklists.MonthReport.create
      isLoaded: false
      site: site
      year: year
      month: month
      summary: Ember.A()
    $.ajax
      url: "/api/v1.0/checklist/report/#{site}/#{year}/#{month}",
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
  didInsertElement: ->
    Mousetrap.bind ['ctrl+s', 'command+s'], ->
      Checklists.get('router').send('saveChecklist')
      false
  willDestroyElement: ->
    Mousetrap.unbind ['ctrl+s', 'command+s']

Checklists.ChecklistController = Ember.ObjectController.extend
  content: null

Checklists.Checklist = Ember.ObjectController.extend
  site: ''
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

Checklists.ChecksGroup = Ember.Object.extend
  name: ''
  title: ''
  checks: ''
  collapsed: false # Move to controller

Checklists.ChecklistRepository = Ember.Object.create
  checklistsCache: {}
  cleanCache: ->
    @get('checklistsCache').set({})
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
  newChecklist: (site, date) ->
    Checklists.Checklist.create
      site: site
      name: ''
      date: date
      closed: false
      groups: []
  findOne: (site, date) ->
    if @get('checklistsCache')["#{site}-#{date}"]?
      @get('checklistsCache')["#{site}-#{date}"]
    else
      checklist = @newChecklist(site, date)
      @get('checklistsCache')["#{site}-#{date}"] = checklist
      $.ajax
        url: "/api/v1.0/checklist/#{site}/#{date}",
        success: (response) =>
          @checklistFillJson(checklist, response)
      checklist
  saveChecklist: (checklist) ->
    checklist.set('isSaved', false)
    $.ajax
      url: "/api/v1.0/checklist/#{checklist.site}/#{checklist.date}",
      type: 'POST'
      contentType: 'application/json'
      data: JSON.stringify(checklist)
      success: (response) =>
        checklist.setProperties(response)
        groups = Ember.A()
        groups.addObject(Checklists.ChecklistRepository.checklistGroupFromJson(g)) for g in response.groups
        checklist.set('groups', groups)
        @get('checklistsCache')["#{checklist.site}-#{checklist.date}"] = checklist
        checklist.set('isSaved', true)
      error: (response) =>
        msg = response.responseText.msg
        bootbox.alert("The checklist is already closed, cannot save!!")
        checklist.set('closed', true)
        checklist.set('isSaved', true)

Checklists.Router = Ember.Router.extend
  enableLogging: true
  setupReportsController: (site) ->
    this.get('reportsMenuController').set('content', Checklists.ReportRepository.loadMenuSet(site))
  root: Ember.Route.extend
    goToMain: Ember.Router.transitionTo('index')
    goToDay: Ember.Router.transitionTo('checklist')
    index: Ember.Route.extend
      route: '/'
      siteChecklist: Ember.Router.transitionTo('checklist')
      connectOutlets: (router) ->
        router.get('applicationController').connectOutlet('toolbar', 'toolbar')
        router.get('toolbarController').set('inChecklist', false)
        router.get('toolbarController').set('inReport', false)
        router.get('applicationController').connectOutlet('main', 'sites', Checklists.SitesRepository.findAll())
    checklist: Ember.Route.extend
      route: '/:site/:date'
      saveChecklist: (router) ->
        checklist =  router.get('checklistController').get('content')
        Checklists.ChecklistRepository.saveChecklist(checklist)
      closeChecklist: (router) ->
        checklist =  router.get('checklistController').get('content')
        checklist.set('closed', true)
        Checklists.ChecklistRepository.saveChecklist(checklist)
      goToPrevious: (router) ->
        checklist =  router.get('checklistController').get('content')
        # current date
        previousDay = moment(checklist.get('date'), Checklists.urlDateFormat).subtract('days', 1)
        router.transitionTo('checklist', {site: checklist.get('site'), date: previousDay.format(Checklists.urlDateFormat)})
      goToNext: (router) ->
        checklist =  router.get('checklistController').get('content')
        # current date
        nextDay = moment(checklist.get('date'), Checklists.urlDateFormat).add('days', 1)
        router.transitionTo('checklist', {site: checklist.get('site'), date: nextDay.format(Checklists.urlDateFormat)})
      connectOutlets: (router, site) ->
        router.setupReportsController(site.site)
        checklist = Checklists.ChecklistRepository.findOne(site.site, site.date)

        router.get('toolbarController').set('inChecklist', true)
        router.get('toolbarController').set('site', site.site)
        router.get('applicationController').connectOutlet('toolbar', 'toolbar')
        router.get('applicationController').connectOutlet('main', 'checklist', checklist)

        router.get('templateSettingsController').set('content', Checklists.TemplateRepository.findSettings(site.site))
    editTemplate: Ember.Router.transitionTo('template')
    template: Ember.Route.extend
      route: '/:site/template'
      connectOutlets: (router, context) ->
        template = Checklists.TemplateRepository.findTemplate(context)
        router.get('toolbarController').set('inChecklist', false)
        router.get('templateController').set('content', template)
        router.get('applicationController').connectOutlet('main', 'template', template)
        router.get('applicationController').connectOutlet('toolbar', 'toolbar')
      saveTemplate: (router) ->
        template =  router.get('templateController').get('content')
        Checklists.TemplateRepository.saveTemplate(template)
      serialize: (router, context) ->
        site: context.get('site')
      deserialize: (router, urlParams) ->
        context = Ember.Object.create
          site: urlParams.site
          name: ''
        Checklists.TemplateRepository.findTemplate(context)
    moveToMonthReport: Ember.Router.transitionTo('report.monthReport')
    report: Ember.Route.extend
      route: '/report'
      monthReport: Ember.Route.extend
        route: '/:site/:year/:month'
        connectOutlets: (router, context) ->
          router.setupReportsController(context.get('site'))
          router.get('applicationController').connectOutlet('toolbar', 'toolbar')
          router.get('toolbarController').set('inReport', true)
          router.get('toolbarController').set('inChecklist', false)
          report = Checklists.ReportRepository.loadReport(context.get('site'), context.get('year'), context.get('month'))
          router.get('applicationController').connectOutlet('main', 'reports', report)
        serialize: (router, context) ->
          site: context.get('site')
          month: context.get('month')
          year: context.get('year')
        deserialize: (router, urlParams) ->
          context = Ember.Object.create
            site: urlParams.site
            month: urlParams.month
            year: urlParams.year
            year: urlParams.year

Checklists.initialize()