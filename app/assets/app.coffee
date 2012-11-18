App = Ember.Application.create()

App.ApplicationView = Ember.View.extend
  templateName: 'application'
App.ApplicationController = Ember.Controller.extend()

App.GS = Ember.Object.create
  name: 'Gemini South'
  shortcut: 'GS'

App.GN = Ember.Object.create
  name: 'Gemini North'
  shortcut: 'GN'

App.SiteSelectorController = Ember.ArrayController.extend
  content: Ember.A([App.GS, App.GN  ])

App.SiteSelectorView = Ember.View.extend
  templateName: 'select_sites'

App.SiteChecklistController = Ember.ObjectController.extend()

App.SiteChecklistView = Ember.View.extend
  templateName: 'site_checklist'

App.Router = Ember.Router.extend
  enableLogging: true,
  root: Ember.Route.extend
    index: Ember.Route.extend
      route: '/',
      connectOutlets: (router) ->
        router.get('applicationController').connectOutlet('siteSelector')
      showSite:  Ember.Route.transitionTo('site')
    site: Ember.Route.extend
      route: '/:site',
      connectOutlets: (router, context) ->
        router.get('applicationController').connectOutlet('siteChecklist', context)
      serialize: (router, context) ->
        console.log(context)
        site: context.get('shortcut')

App.initialize()