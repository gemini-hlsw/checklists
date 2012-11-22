window.Checklists = Ember.Application.create()

Checklists = window.Checklists
###
# Utility functions
###
Checklists.formatDate = (date) ->
  $.format.date(date, 'yyyyMMdd')

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

Checklists.CheckValues = ['done', 'not done', 'NA', 'Ok', 'pending', 'not Ok']

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

Checklists.ChecklistRepository = Ember.Object.create
  findOne: (site, date) ->
    checklist = Checklists.Checklist.create
      site: ''
      name: ''
      date: ''
      groups: []
    console.log(typeof checklist)
    $.ajax
      url: "/api/v1.0/checklist/#{site}/#{date}",
      success: (response) =>
        checklist.setProperties(response)
        checklist.get('groups').forEach (v)->
          console.log(v.checks)
    checklist

Checklists.Router = Ember.Router.extend
  location : "hash"
  enableLogging: true
  root: Ember.Route.extend
    index: Ember.Route.extend
      route: '/'
      siteChecklist: Ember.Router.transitionTo('checklist')
      connectOutlets: (router, context) ->
        router.get('applicationController').connectOutlet('sites', Checklists.SitesRepository.findAll())
    checklist: Ember.Route.extend
      route: '/:site/:date'
      connectOutlets: (router, site) ->
        router.get('applicationController').connectOutlet('checklist', Checklists.ChecklistRepository.findOne(site.site, site.date))

Checklists.initialize()