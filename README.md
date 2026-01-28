# stinkingtoe 

Add comments to your ActiveRecord queries. By default, this appends the application, controller, and action names as a comment to each query.

This is useful for tracking queries in log files and identifying the source of slow queries.

For example, once enabled, your logs will look like:

    Account Load (0.3ms)  SELECT `accounts`.* FROM `accounts` 
    WHERE `accounts`.`queenbee_id` = 1234567890 
    LIMIT 1 
    /*application:APP,controller:project_imports,action:show*/

## Installation

    # Gemfile
    gem 'stinkingtoe'

### Customization

Optionally, you can set the application name shown in the log like so in an initializer (e.g. `config/initializers/stinkingtoe.rb`):

    StinkingToe.application_name = "APP"

The name will default to your Rails application name.

#### Components

You can also configure the components of the comment that will be appended,
by setting `StinkingToe::Comment.components`. By default, this is set to:

    StinkingToe::Comment.components = [:application, :controller, :action]

Which results in a comment of
`application:#{application_name},controller:#{controller.name},action:#{action_name}`.

You can re-order or remove these components. You can also add additional
comment components of your desire by defining new module methods for
`StinkingToe::Comment` which return a string. For example:

    module StinkingToe
      module Comment
        def self.mycommentcomponent
          "TEST"
        end
      end
    end

    StinkingToe::Comment.components = [:application, :mycommentcomponent]

Which will result in a comment like
`application:#{application_name},mycommentcomponent:TEST`
The calling controller is available to these methods via `@controller`.

StinkingToe ships with `:application`, `:controller`, and `:action` enabled by
default. In addition, implementation is provided for:
  * `:line` (for file and line number calling query). :line supports
    a configuration by setting a regexp in `StinkingToe::Comment.lines_to_ignore`
    to exclude parts of the stacktrace from inclusion in the line comment.
  * `:controller_with_namespace` to include the full classname (including namespace)
    of the controller.
  * `:job` to include the classname of the ActiveJob being performed.
  * `:hostname` to include ```Socket.gethostname```.
  * `:pid` to include current process id. 
  * `:db_host` to include the configured database hostname.
  * `:socket` to include the configured database socket.
  * `:database` to include the configured database name.

Pull requests for other included comment components are welcome.

#### Prepend comments

By default, `stinkingtoe` appends comments at the end of queries. Some databases, like MySQL, truncate query text—for example, in slow query logs and certain InnoDB internal table queries where the query exceeds 1024 bytes.

In order to not lose the `stinkingtoe` comments from your logs, you can prepend the comments using this option:

    StinkingToe::Comment.prepend_comment = true

#### Inline query annotations

In addition to the request or job-level component-based annotations,
`stinkingtoe` may be used to add inline annotations to specific queries using a
block-based API.

For example, the following code:

    StinkingToe.with_annotation("foo") do
      Account.where(queenbee_id: 1234567890).first
    end

will issue this query:

    Account Load (0.3ms)  SELECT `accounts`.* FROM `accounts`
    WHERE `accounts`.`queenbee_id` = 1234567890
    LIMIT 1
    /*application:APP,controller:project_imports,action:show*/ /*foo*/

Nesting `with_annotation` blocks will concatenate the comment strings.

### Caveats

#### Prepared statements

Be careful when using `stinkingtoe` with prepared statements. If you use a component
like `request_id` then every query will be unique and so ActiveRecord will create
a new prepared statement for each potentially exhausting system resources.
[Disable prepared statements](https://guides.rubyonrails.org/configuring.html#configuring-a-postgresql-database)
if you wish to use components with high cardinality values.

## Contributing

Start by bundling and creating the test database:

    bundle
    rake db:mysql:create
    rake db:postgresql:create

Then, running `rake` will run the tests on all the database adapters (`mysql`, `mysql2`, `postgresql` and `sqlite`):

    rake