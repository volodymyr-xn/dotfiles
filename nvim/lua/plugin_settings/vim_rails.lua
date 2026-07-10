-- ================================= vim-rails settings ========================
-- example projections: https://gist.github.com/henrik/5676109
vim.g.rails_projections = {
  ['app/components/*.rb'] = {
    -- alternate = 'app/components/{}.haml',
    alternate = 'app/components/{}.html.erb',
    related = 'app/components/{}.js',
  },
  ['app/components/*.haml'] = {
    alternate = 'app/components/{}.scss',
    related = 'app/components/{}.js',
  },
  ['app/components/*.html.erb'] = {
    alternate = 'app/components/{}.rb',
    related = 'app/components/{}.scss',
  },
  ['app/components/*.js'] = {
    alternate = 'app/components/{}.rb',
    related = 'app/components/{}.scss',
  },
  ['app/components/*.scss'] = {
    alternate = 'app/components/{}.rb',
  },
  -- Models in custom/ overlay dirs are NOT namespaced (Consul autoload
  -- overlay), so strip "custom/" before deriving the schema table anchor.
  ['app/models/custom/*.rb'] = {
    related = 'db/schema.rb#{underscore|plural}',
  },
  -- No 'app/*.rb' alternate on purpose: a projection short-circuits
  -- rails.vim's own candidate list (autoload/rails.vim:3701), and that list
  -- already tries test/{}_test.rb, the old test/unit|functional layout and
  -- spec/{}_spec.rb, dropping whichever of test/ or spec/ the project does
  -- not have. Hardcoding the spec path broke `:A` in minitest projects.
  ['app/admin/*.rb'] = {
    alternate = 'spec/controllers/admin/{}_controller_spec.rb',
  },
  ['spec/controllers/admin/*_controller_spec.rb'] = {
    alternate = 'app/admin/{}.rb',
  },
}

vim.g.rails_gem_projections = {
  activeadmin = {
    ['app/admin/*.rb'] = {
      command = 'admin',
      affinity = 'model',
      alternate = 'app/models/{}.rb',
      template = 'ActiveAdmin.register {} do\nend',
    },
  },
}
