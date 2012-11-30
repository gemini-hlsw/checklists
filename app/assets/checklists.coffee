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
    console.log(@get('data'))
    console.log(@get('inputFormat'))
    c = moment(@get('data'), @get('inputFormat'))
    console.log c.toDate()
    c.format(Checklists.calendarFormattedDate)
  ).property('data'),
  dataBinding: null,
  didInsertElement: ->
    self = this
    $('.date').datepicker
      format: @get('format')
    $('.date').on 'changeDate', (ev) =>
      self.set('data', ev.date)
      $('.date').datepicker('hide')
      console.log(@get('data'))

###
# View and controller to edit a template
###
Checklists.TemplateView = Ember.View.extend
  templateName: 'edit_template'
Checklists.TemplateController = Ember.ObjectController.extend
  content: null

###
# View and controller for the toolbar
###
Checklists.ToolbarView = Ember.View.extend
  templateName: 'toolbar'
Checklists.ToolbarController = Ember.ObjectController.extend
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
  groups: []
  isLoaded: false
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
        @checklistsCache["#{site}-#{date}"] = checklist

Checklists.Router = Ember.Router.extend
  location : "hash"
  enableLogging: true
  root: Ember.Route.extend
    index: Ember.Route.extend
      route: '/'
      siteChecklist: Ember.Router.transitionTo('checklist')
      connectOutlets: (router) ->
        router.get('applicationController').connectOutlet('main', 'sites', Checklists.SitesRepository.findAll())
    checklist: Ember.Route.extend
      route: '/:site/:date'
      saveChecklist: (router) ->
        checklist =  router.get('checklistController').get('content')
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
        router.get('applicationController').connectOutlet('main', 'template', {site: context.get('site')})

Checklists.initialize()