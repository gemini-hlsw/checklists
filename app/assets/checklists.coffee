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
    $.ajax
      url: '/api/v1.0/sites'
      success: (response) ->
        response.forEach (site) =>
          self.sites.pushObject(Checklists.SitesRepository.createFromJson(site))

    self.sites

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
      route: '/:site'
      connectOutlets: (router, site) ->
        router.get('applicationController').connectOutlet('sites', Checklists.SitesRepository.findAll())

Checklists.initialize()