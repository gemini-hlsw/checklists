window.Checklists = Ember.Application.create()

Ember.LOG_BINDINGS = true

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
    t = g for g in @get('controller.content.groups') when g.name is event.context
    nc = Checklists.TemplateCheck.create
      title: ''
    t.get('checks').insertAt(0, nc)
  deleteGroup: (event) ->
    name = event.context
    g = @get('controller.content.groups')
    g = (i for i in g when i.name isnt name)
    @set('controller.content.groups', g)
Checklists.TemplateController = Ember.ObjectController.extend
  content: null

Checklists.Template = Ember.Object.extend
  site: ''
  name: ''
  groups: []
  isLoaded: false
Checklists.TemplateCheck = Ember.Object.extend
  title: ''
Checklists.TemplateGroup = Ember.Object.extend
  name: ''
  title: ''
  checks: Ember.A()

Checklists.TemplateRepository = Ember.Object.create
  templates: {}
  checkFromJson: (json) ->
    Checklists.TemplateCheck.create
      title: json.title
  groupFromJson: (json) ->
    group = Checklists.TemplateGroup.create
      name: ''
      title: ''
      checks: Ember.A()
    group.setProperties(json)
    checks = Ember.A()
    checks.addObject(Checklists.TemplateRepository.checkFromJson(c)) for c in json.checks
    group.set('checks', checks)
  findTemplate: (site) ->
    key = site.get('site')
    if @templates[key]?
      @templates[key]
    else
      template = Checklists.Template.create
        site: key
        name: site.get('name')
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
    $.ajax
      url: "/api/v1.0/templates/#{template.site}",
      type: 'POST'
      contentType: 'application/json'
      data: JSON.stringify(template)
      success: (response) =>
        console.log(response)

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
  switchToClear: ->
    Checklists.switchStyle('clear')
  switchToDark: ->
    Checklists.switchStyle('dark')
Checklists.ToolbarController = Ember.ObjectController.extend
  content: null

###
# View and controller for the toolbar
###
Checklists.ToolbarTemplateView = Ember.View.extend
  templateName: 'toolbar_template'
  showAbout: ->
    alert("About")

Checklists.ToolbarTemplateController = Ember.ObjectController.extend
  content: null

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

  findOne: (site, date) ->
    if @checklistsCache["#{site}-#{date}"]?
      @checklistsCache["#{site}-#{date}"]
    else
      checklist = Checklists.Checklist.create
        site: site
        name: ''
        date: date
        closed: false
        groups: []
      @checklistsCache["#{site}-#{date}"] = checklist
      $.ajax
        url: "/api/v1.0/checklist/#{site}/#{date}",
        success: (response) =>
          checklist.setProperties(response)
          groups = Ember.A()
          groups.addObject(Checklists.ChecklistRepository.checklistGroupFromJson(g)) for g in response.groups
          checklist.set('groups', groups)
          checklist.set('isLoaded', true)
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
  location : "hash"
  enableLogging: true
  root: Ember.Route.extend
    index: Ember.Route.extend
      route: '/'
      siteChecklist: Ember.Router.transitionTo('checklist')
      connectOutlets: (router) ->
        router.get('applicationController').connectOutlet('main', 'sites', Checklists.SitesRepository.findAll())
        router.get('applicationController').connectOutlet('toolbar', 'toolbarTemplate')
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
        checklist = Checklists.ChecklistRepository.findOne(site.site, site.date)
        router.get('applicationController').connectOutlet('main', 'checklist', checklist)
        router.get('applicationController').connectOutlet('toolbar', 'toolbar', checklist)
    editTemplate: Ember.Router.transitionTo('template')
    template: Ember.Route.extend
      route: '/:site/template'
      connectOutlets: (router, context) ->
        router.get('applicationController').connectOutlet('toolbar', 'toolbarTemplate', context)
        template = Checklists.TemplateRepository.findTemplate(context)
        router.get('templateController').set('content', template)
        router.get('applicationController').connectOutlet('main', 'template', template)
        router.get('applicationController').connectOutlet('toolbar', 'toolbarTemplate')
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

Checklists.initialize()

if Modernizr.localstorage
  if not localStorage.theme?
    localStorage.theme = 'dark'
  Checklists.switchStyle(localStorage.theme)