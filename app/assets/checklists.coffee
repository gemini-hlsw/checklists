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

Checklists.Site = Ember.Object.extend
  site: ''
  name: ''

Checklists.SitesView = Ember.View.extend
  templateName: 'sites'
Checklists.SitesController = Ember.ArrayController.extend
  content: []

Checklists.SitesRepository = Ember.Object.create
  findAll: ->
    gs = Checklists.Site.create
      site: 'GS'
      name: 'Gemini South'
    gn = Checklists.Site.create
      site: 'GN'
      name: 'Gemini North'
    [gs, gn]

Checklists.Router = Ember.Router.extend
  enableLogging: true
  root: Ember.Route.extend
    index: Ember.Route.extend
      route: '/'
      connectOutlets: (router, context) ->
        router.get('applicationController').connectOutlet('sites', Checklists.SitesRepository.findAll())

Checklists.initialize()