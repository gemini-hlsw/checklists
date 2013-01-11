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
    true

# Displays an overlay with a spinning wheel and a message
Checklists.SavingOverlayView = Ember.View.extend
  templateName: 'saving_overlay'
  didInsertElement: ->
    this._super()
    this.$('.overlay').spin('large', 'white')

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
# View and controller to edit a template
###
Checklists.TemplateView = Ember.View.extend
  templateName: 'edit_template'
  addGroup: () ->
    confirm = (result) =>
      if result?
        group = Checklists.TemplateGroup.create
          name: result
          title: result
          checks: Ember.A()
        @get('controller.content.groups').insertAt(0, group)
    bootbox.prompt("Enter the group name:", "Cancel", "OK", confirm, "New Group")
  addCheck: (event) ->
    @get('controller.content').addCheck(event.context)
  deleteGroup: (event) ->
    name = event.context
    g = @get('controller.content.groups')
    g = (i for i in g when i.name isnt name)
    @set('controller.content.groups', g)
  deleteCheck: (event) ->
    t = g for g in @get('controller.content.groups') when g.name is event.contexts[1].get('name')
    c = t.get('checks').find (e)->
      e.get('pos') is event.context.get('pos')
    t.get('checks').removeObject(c)

Checklists.TemplateController = Ember.ObjectController.extend
  content: null

Checklists.Template = Ember.Object.extend
  site: ''
  name: ''
  groups: []
  isLoaded: false
  isSaved: true
  canDisplay: ( ->
    @get('isLoaded') and @get('isSaved')
  ).property('isLoaded', 'isSaved')
  addCheck: (name) ->
    t = g for g in @get('groups') when g.name is name
    nc = Checklists.TemplateCheck.create
      title: ''
      position: t.get('checks').length
    t.get('checks').pushObject(nc)

Checklists.TemplateCheck = Ember.Object.extend
  title: ''
  position: 0

Checklists.TemplateGroup = Ember.Object.extend
  name: ''
  title: ''
  checks: Ember.A()

Checklists.TemplateRepository = Ember.Object.create
  templates: {}
  checkFromJson: (json, index) ->
    Checklists.TemplateCheck.create
      title: json.title
      position: index
  groupFromJson: (json) ->
    group = Checklists.TemplateGroup.create
      name: ''
      title: ''
      checks: Ember.A()
    group.setProperties(json)
    checks = Ember.A(Checklists.TemplateRepository.checkFromJson(c, i) for c, i in json.checks)
    group.set('checks', checks)
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
  day: (->
    moment(@get('date'), Checklists.urlDateFormat).date()
  ).property('date')
  notClosed: (->
    not @get('closed')
  ).property('closed')
  summaryText: (->
    status = @get('status')
    ["#{p}: #{status[p]}" for p of status].join(', ')
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

Checklists.ChecklistRepository = Ember.Object.create
  checklistsCache: {}
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
    if @checklistsCache["#{site}-#{date}"]?
      @checklistsCache["#{site}-#{date}"]
    else
      checklist = @newChecklist(site, date)
      @checklistsCache["#{site}-#{date}"] = checklist
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
        @checklistsCache["#{checklist.site}-#{checklist.date}"] = checklist
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