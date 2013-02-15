App = Ember.Application.create({});

var parentsCount = 10;
var childrenCount = 10;

App.ApplicationController = Ember.Controller.extend({});
App.ApplicationView = Ember.View.extend({
    templateName: 'application'
});

App.IndexView = Ember.View.extend({
    templateName: 'index'
});
App.IndexController = Ember.ArrayController.extend({
    load: function () {
        var content = Ember.A();
        for (i = 0; i < parentsCount; i++) {
            var children = Ember.A();
            for (j = 0; j < childrenCount; j++) {
                var c = App.Child.create({
                    position: j
                });
                children.pushObject(c);
            }
            var p = App.Parent.create({
                id: i,
                children: children
            });
            content.pushObject(p);
        }
        this.set('content', content);
    }
});

App.Child = Ember.Object.extend({
    position: -1
});

App.Parent = Ember.Object.extend({
    id: 0,
    children: null
});

App.Router = Ember.Router.extend({
  enableLogging: true,
  root: Ember.Route.extend({
    index: Ember.Route.extend({
      route: '/',
      connectOutlets: function(router) {
        router.get('indexController').set('content', Ember.A())
        router.get('applicationController').connectOutlet('index')
    }
        })
    })
});

App.initialize();
