App = Ember.Application.create({});

var parentsCount = 10;
var childrenCount = 10;

App.IndexController = Ember.ArrayController.extend({
    load: function () {
        var content = Ember.A();
        for (i = 0; i < parentsCount; i++) {
            var children = Ember.A();
            for (j = 0; j < childrenCount; j++) {
                var c = App.Child.create({
                    position: j,
                    status: 'done',
                    comment: 'it (' + i + ", " +j +")"
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
    position: -1,
    status: null,
    comment: null
});

App.Parent = Ember.Object.extend({
    id: 0,
    children: null
});

App.CheckValues = Ember.A(['', 'done', 'not done', 'NA', 'Ok', 'pending', 'not Ok']);


App.ApplicationController = Ember.Controller.extend({});
App.ApplicationView = Ember.View.extend({
    templateName: 'application'
});

App.IndexView = Ember.View.extend({
    templateName: 'index'
});

App.RowView = Ember.ContainerView.extend({
    childViews: ['pView', 'sView', 'cView'],
    tagName: 'ul',
    choices: Ember.A(['a', 'b']),
    positionBinding: 'context.position',
    statusBinding: 'context.status',
    commentBinding: 'context.comment',
    pView: Ember.View.extend({
        templateName: 'row_pos',
        tagName: 'li',
    }),
    sView: Ember.View.extend({
        templateName: 'row_st',
        tagName: 'li',
        didInsertElement: function() {
            console.log(this.$())
        }
    }),
    cView: Ember.View.extend({
        templateName: 'row_com',
        tagName: 'li',
    })
});

App.RowsView = Ember.CollectionView.extend({
  tagName: 'ul',
  itemViewClass: App.RowView
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
