window.App = Ember.Application.create()

###
# Utility functions
###
App.formatDate = (date) ->
  $.format.date(date, 'yyyyMMdd')

###
# Top level controller and view
###
App.ApplicationController = Ember.Controller.extend()

App.ApplicationView = Ember.View.extend
  templateName: 'application'

App.CheckValues = ['done', 'not done', 'NA', 'Ok', 'pending', 'not Ok']

###
# One item on the checklist
###
App.ChecklistItem = Ember.Object.extend()
App.ChecklistItem.reopenClass
  createFromJson: (json) ->
    App.ChecklistItem.create
      description: json.description
      status: null
      comment: json.comment

###
# Group of items on the checklist
###
App.ChecksGroup = Ember.ArrayController.extend()
App.ChecksGroup.reopenClass
  createFromJson: (json) ->
    checks = Ember.A([])
    checks.addObject(App.ChecklistItem.createFromJson(g)) for g in json.checks
    Ember.Object.create
      title: json.title
      name: json.name
      checks: checks

App.ChecksGroups = Ember.ArrayController.extend()
App.ChecksGroups.reopenClass
  createFromJson: (json) ->
    checks = Ember.A([])
    checks.addObject(App.ChecklistItem.createFromJson(g)) for g in json.checks

App.SiteChecklistGroupsController = Ember.ArrayController.extend
  content: Ember.A()

App.Checklist = Ember.Object.extend
  formattedDate: ( ->
    App.formatDate(@get('date')) if @get('date')
  ).property('date')

App.Checklist.reopenClass
  updateFromJson: (checklist, json) ->
    checklist.set('site', json.site)
    checklist.set('name', json.name)
    checklist.set('date', new Date(json.date))
    groups = Ember.A([])
    groups.addObject(App.ChecksGroup.createFromJson(g)) for g in json.groups
    checklist.set('groups', groups)

App.SiteChecklistController = Ember.ObjectController.extend()

App.SiteChecklistController.reopenClass
  findChecklist: (site) ->
    console.log(site)
    clDate = if site.date then site.date else App.formatDate(new Date())

    checklist = App.Checklist.create
      site: site.site
      date: clDate
    console.log("date " + clDate)
    siteName = site.site
    debugger
    content = App.SiteChecklistController.get('content')
    if (content.site isnt checklist.site and content.date isnt checklist.date)
      $.ajax
        url: "/api/v1.0/checklist/#{siteName}/#{clDate}",
        success: (response, code) =>
          App.Checklist.updateFromJson(checklist, response)
    App.SiteChecklistController.set('content', checklist)
    checklist
  saveChecklist: (checklist) ->
    date = App.formatDate(checklist.date)
    $.ajax
      url: "/api/v1.0/checklist/#{checklist.site}/#{date}",
      type: 'POST'
      contentType: 'application/json'
      data: JSON.stringify(checklist)
      success: (response, code) =>
        console.log(response)

App.SiteChecklistView = Ember.View.extend
  templateName: 'site_checklist'

App.SiteChecklistTemplate = Ember.ArrayController.extend
  content: Ember.A
  site: ''
  name: ''

App.Site = Ember.ObjectController.extend
  formattedDate: ( ->
     App.formatDate(@get('date')) if @get('date')
   ).property('date')

App.Site.reopenClass
  createFromJson: (site) ->
    App.Site.create
      site: site.site
      name: site.name
      date: new Date()

###
# Controller and view to select a site
###
App.SiteSelectorController = Ember.ArrayController.extend()

App.SiteSelectorController.reopenClass
  content: Ember.A(),
  findSites: ->
    if @content.length is 0
      $.ajax
        url: '/api/v1.0/sites'
        context: this
        success: (response) ->
          response.forEach (site) =>
            @content.addObject(App.Site.createFromJson(site))
    @content

App.SiteSelectorView = Ember.View.extend
  templateName: 'select_sites'

App.Router = Ember.Router.extend
  enableLogging: true
  root: Ember.Route.extend
    index: Ember.Route.extend
      route: '/',
      connectOutlets: (router, context) ->
        router.get('applicationController').connectOutlet('siteSelector', App.SiteSelectorController.findSites())
      showSite: Ember.Route.transitionTo('checklist')
    checklist: Ember.Route.extend
      route: '/:site/:date'
      connectOutlets: (router, context) ->
        checklist = App.SiteChecklistController.findChecklist(context)
        checklistController = router.get('siteChecklistController')
        checklistController.set('content', checklist)

        router.get('applicationController').connectOutlet('siteChecklist')
      serialize: (router, context) ->
        console.log("serial")
        console.log(context)
        site: context.get('site')
        date: context.get('formattedDate')
      deserialize: (router, urlParams) ->
        console.log("Deserial")
        console.log(urlParams)
        App.SiteChecklistController.findChecklist(urlParams)
      saveChecklist: (router, event) ->
        App.SiteChecklistController.saveChecklist(event.context)


App.initialize()