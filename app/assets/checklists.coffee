window.Checklists = Ember.Application.create()

Checklists = window.Checklists
###
# Utility functions
###
Checklists.dateFormat = 'YYYYMMDD'

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

###
# View and controller for the calendar
###
Checklists.CalendarView = Ember.View.extend
  templateName: 'calendar'
  didInsertElement: ->
    $('#date_picker').datepicker('place')
Checklists.CalendarController = Ember.ObjectController.extend
  content: null

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
  formattedDate: ( ->
    d = moment(@get('date'), 'YYYYMMDD')
    if d? then d.format('dddd, MMMM Do YYYY') else ''
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
        previousDay = moment(checklist.get('date'), 'YYYYMMDD').subtract('days', 1)
        router.transitionTo('checklist', {site: checklist.get('site'), date: previousDay.format('YYYYMMDD')})
      goToNext: (router) ->
        checklist =  router.get('checklistController').get('content')
        # current date
        nextDay = moment(checklist.get('date'), 'YYYYMMDD').add('days', 1)
        router.transitionTo('checklist', {site: checklist.get('site'), date: nextDay.format('YYYYMMDD')})
      connectOutlets: (router, site) ->
        checklist = Checklists.ChecklistRepository.findOne(site.site, site.date)
        router.get('applicationController').connectOutlet('main', 'checklist', checklist)
        router.get('applicationController').connectOutlet('toolbar', 'toolbar', checklist)


Checklists.initialize()