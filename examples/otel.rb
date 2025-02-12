# This file contains a basic OpenTracing example.
#
# Note:  The instana gem automatically sets the Instana tracer
# to `OpenTracing.global_tracer`.  Once the gem is loaded, you can
# immediately start making OpenTracing calls.
#

# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2018

require "opentracing"

entry_span = OpenTracing.start_span("HandMadeRackServer")

entry_span.set_tag(:'http.method', :get)
entry_span.set_tag(:'http.url', "/users")
entry_span.set_tag(:'span.kind', "entry")

intermediate_span = OpenTracing.start_span("myintermediate", :child_of => entry_span)
intermediate_span.finish

db_span = OpenTracing.start_span('mydbspan', :child_of => entry_span)
db_span.set_tag(:'db.instance', "users")
db_span.set_tag(:'db.statement', "SELECT * FROM user_table")
db_span.set_tag(:'db.type', "mysql")
db_span.set_tag(:'db.user', "mysql_login")
db_span.set_tag(:'span.kind', "exit")
db_span.finish

intermediate_span = OpenTracing.start_span("myintermediate", :child_of => entry_span)
intermediate_span.log("ALLOK", :message => "All seems ok")
intermediate_span.finish

entry_span.set_tag(:'http.status_code', 200)
entry_span.finish
