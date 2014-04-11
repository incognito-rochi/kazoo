%%%-------------------------------------------------------------------
%%% @copyright (C) 2011-2014, 2600Hz
%%% @doc
%%% Handles authentication requests, responses, queue bindings
%%% @end
%%% @contributors
%%%   Luis Azedo
%%%-------------------------------------------------------------------
-module(wapi_gsm).

-compile({no_auto_import, [error/1]}).

-export([
         nonce_req/1, nonce_req_v/1
         ,nonce_resp/1, nonce_resp_v/1

         ,authn_req/1, authn_req_v/1
         ,authn_resp/1, authn_resp_v/1
        
         ,error/1, error_v/1
         ,success/1, success_v/1                
                
         ,bind_q/2, unbind_q/2
         ,declare_exchanges/0

         ,publish_nonce_req/1, publish_nonce_req/2
         ,publish_nonce_resp/2, publish_nonce_resp/3        
        
         ,publish_authn_req/1, publish_authn_req/2
         ,publish_authn_resp/2, publish_authn_resp/3        

         ,publish_error/2, publish_error/3
         ,publish_success/2, publish_success/3

         ,route_req/1, route_req_v/1
         ,route_resp/1, route_resp_v/1

         ,publish_route_req/1, publish_route_req/2
         ,publish_route_resp/2, publish_route_resp/3
        
         ,is_actionable_resp/1        

        ]).

-include_lib("whistle/include/wh_api.hrl").

-define(EVENT_CATEGORY, <<"gsm">>).
-define(KEY_GSM_REQ, <<"gsm.req">>).

-define(NONCE_REQ_EVENT_NAME, <<"nonce_req">>).

-define(NONCE_REQ_HEADERS, [<<"To">>, <<"From">>
                            ,<<"Auth-User">>, <<"Auth-Realm">>
                           ]).
-define(OPTIONAL_NONCE_REQ_HEADERS, [<<"Method">>, <<"Switch-Hostname">>
                                    ,<<"Orig-IP">>, <<"Call-ID">>
                                    ,<<"Auth-Nonce">>, <<"Auth-Response">>
                                    ]).
-define(NONCE_REQ_VALUES, [{<<"Event-Category">>, ?EVENT_CATEGORY}
                           ,{<<"Event-Name">>, ?NONCE_REQ_EVENT_NAME}
                          ]).
-define(NONCE_REQ_TYPES, [{<<"To">>, fun is_binary/1}
                          ,{<<"From">>, fun is_binary/1}
                          ,{<<"Orig-IP">>, fun is_binary/1}
                          ,{<<"Auth-User">>, fun is_binary/1}
                          ,{<<"Auth-Realm">>, fun is_binary/1}
                         ]).

%% Authentication Responses
-define(NONCE_RESP_EVENT_NAME, <<"nonce_resp">>).

-define(NONCE_RESP_HEADERS, []).
-define(OPTIONAL_NONCE_RESP_HEADERS, [<<"Custom-Channel-Vars">>
                                      ,<<"Auth-Nonce">>
                                      ,<<"Auth-Method">>, <<"Auth-Password">>
                                      ,<<"Auth-Username">> ,<<"Account-Realm">>
                                      ,<<"Account-Name">> ,<<"GSM-KC">>
                                      ,<<"Suppress-Unregister-Notifications">>
                                      ,<<"Register-Overwrite-Notify">>
                                     ]).
-define(NONCE_RESP_VALUES, [{<<"Event-Category">>, ?EVENT_CATEGORY}
                           ,{<<"Event-Name">>, ?NONCE_RESP_EVENT_NAME}
                          ]).
-define(NONCE_RESP_TYPES, [
                           {<<"Custom-Channel-Vars">>, fun wh_json:is_json_object/1}
                          ]).




-define(AUTHN_REQ_EVENT_NAME, <<"authn_req">>).

-define(AUTHN_REQ_HEADERS, [<<"To">>, <<"From">>
                            ,<<"Auth-User">>, <<"Auth-Realm">>
                           ]).
-define(OPTIONAL_AUTHN_REQ_HEADERS, [<<"Method">>, <<"Switch-Hostname">>
                                    ,<<"Orig-IP">>, <<"Call-ID">>
                                    ,<<"Auth-Nonce">>, <<"Auth-Response">>
                                    ]).
-define(AUTHN_REQ_VALUES, [{<<"Event-Category">>, ?EVENT_CATEGORY}
                           ,{<<"Event-Name">>, ?AUTHN_REQ_EVENT_NAME}
                          ]).
-define(AUTHN_REQ_TYPES, [{<<"To">>, fun is_binary/1}
                          ,{<<"From">>, fun is_binary/1}
                          ,{<<"Orig-IP">>, fun is_binary/1}
                          ,{<<"Auth-User">>, fun is_binary/1}
                          ,{<<"Auth-Realm">>, fun is_binary/1}
                         ]).

%% Authentication Responses
-define(AUTHN_RESP_EVENT_NAME, <<"authn_resp">>).

-define(AUTHN_RESP_HEADERS, [<<"Auth-Method">>, <<"Auth-Password">>]).
-define(OPTIONAL_AUTHN_RESP_HEADERS, [<<"Custom-Channel-Vars">>
                                      ,<<"Auth-Username">>
                                      ,<<"Account-Realm">>
                                      ,<<"Account-Name">>
                                      ,<<"GSM-KC">>
                                      ,<<"GSM-Primary-Number">>
                                      ,<<"Suppress-Unregister-Notifications">>
                                      ,<<"Register-Overwrite-Notify">>
                                     ]).
-define(AUTHN_RESP_VALUES, [{<<"Event-Category">>, ?EVENT_CATEGORY}
                           ,{<<"Event-Name">>, ?AUTHN_RESP_EVENT_NAME}
                           ,{<<"Auth-Method">>, [<<"password">>, <<"ip">>, <<"a1-hash">>, <<"error">>]}
                         ]).
-define(AUTHN_RESP_TYPES, [{<<"Auth-Password">>, fun is_binary/1}
                           ,{<<"Custom-Channel-Vars">>, fun wh_json:is_json_object/1}
                           ,{<<"Access-Group">>, fun is_binary/1}
                           ,{<<"Tenant-ID">>, fun is_binary/1}
                          ]).

%% Authentication Failure Response
-define(AUTHN_ERR_HEADERS, []).
-define(OPTIONAL_AUTHN_ERR_HEADERS, []).
-define(AUTHN_ERR_VALUES, [{<<"Event-Category">>, ?EVENT_CATEGORY}
                          ,{<<"Event-Name">>, <<"authn_err">>}
                         ]).
-define(AUTHN_ERR_TYPES, []).


%% Authentication Success Response
-define(AUTHN_SUCCESS_HEADERS, []).
-define(OPTIONAL_AUTHN_SUCCESS_HEADERS, []).
-define(AUTHN_SUCCESS_VALUES, [{<<"Event-Category">>, ?EVENT_CATEGORY}
                            ,{<<"Event-Name">>, <<"authn_err">>}
                         ]).
-define(AUTHN_SUCCESS_TYPES, []).



-define(ROUTE_REQ_EVENT_NAME, <<"route_req">>).

%% Route Requests
-define(ROUTE_REQ_HEADERS, [<<"To">>, <<"From">>, <<"Request">>, <<"Call-ID">>]).
-define(OPTIONAL_ROUTE_REQ_HEADERS, [<<"Geo-Location">>, <<"Orig-IP">>
                                     ,<<"Max-Call-Length">>, <<"Media">>
                                     ,<<"Transcode">>, <<"Codecs">>
                                     ,<<"Custom-Channel-Vars">>
                                     ,<<"Resource-Type">>, <<"Cost-Parameters">>
                                     ,<<"From-Network-Addr">>
                                     ,<<"Switch-Hostname">>, <<"Switch-Nodename">>
                                     ,<<"Ringback-Media">>, <<"Transfer-Media">>
                                     ,<<"SIP-Request-Host">>, <<"Access-Network-Info">>
                                     ,<<"Physical-Info">>, <<"User-Agent">>
                                     ,<<"Caller-ID-Name">>, <<"Caller-ID-Number">>
                                    ]).
-define(ROUTE_REQ_VALUES, [{<<"Event-Category">>, ?EVENT_CATEGORY}
                           ,{<<"Event-Name">>, ?ROUTE_REQ_EVENT_NAME}
                          ]).
-define(ROUTE_REQ_TYPES, [{<<"To">>, fun is_binary/1}
                          ,{<<"From">>, fun is_binary/1}
                          ,{<<"Request">>, fun is_binary/1}
                          ,{<<"Call-ID">>, fun is_binary/1}
                          ,{<<"Event-Queue">>, fun is_binary/1}
                         ]).


%% Route Responses
-define(ROUTE_RESP_HEADERS, [<<"Custom-Channel-Vars">>]).
-define(OPTIONAL_ROUTE_RESP_HEADERS, []).
-define(ROUTE_RESP_VALUES, [{<<"Event-Category">>, ?EVENT_CATEGORY }
                           ,{<<"Event-Name">>, <<"route_resp">>}
                           ]).
-define(ROUTE_RESP_TYPES, [{<<"Custom-Channel-Vars">>, fun wh_json:is_json_object/1}]).



%%--------------------------------------------------------------------
%% @doc Registration Request - see wiki
%% Takes proplist, creates JSON iolist or error
%% @end
%%--------------------------------------------------------------------
-spec nonce_req(api_terms()) -> {'ok', iolist()} | {'error', string()}.
nonce_req(Prop) when is_list(Prop) ->
        case nonce_req_v(Prop) of
            true -> wh_api:build_message(Prop, ?NONCE_REQ_HEADERS, ?OPTIONAL_NONCE_REQ_HEADERS);
            false -> {error, "Proplist failed validation for authn_req"}
    end;
nonce_req(JObj) ->
    nonce_req(wh_json:to_proplist(JObj)).

-spec nonce_req_v(api_terms()) -> boolean().
nonce_req_v(Prop) when is_list(Prop) ->
    wh_api:validate(Prop, ?NONCE_REQ_HEADERS, ?NONCE_REQ_VALUES, ?NONCE_REQ_TYPES);
nonce_req_v(JObj) ->
    nonce_req_v(wh_json:to_proplist(JObj)).


%%--------------------------------------------------------------------
%% @doc Registration Response - see wiki
%% Takes proplist, creates JSON iolist or error
%% @end
%%--------------------------------------------------------------------
-spec nonce_resp(api_terms()) -> {'ok', iolist()} | {'error', string()}.
nonce_resp(Prop) when is_list(Prop) ->
    case nonce_resp_v(Prop) of
        true -> wh_api:build_message(Prop, ?NONCE_RESP_HEADERS, ?OPTIONAL_NONCE_RESP_HEADERS);
        false -> {error, "Proplist failed validation for authn_resp"}
    end;
nonce_resp(JObj) ->
    nonce_resp(wh_json:to_proplist(JObj)).

-spec nonce_resp_v(api_terms()) -> boolean().
nonce_resp_v(Prop) when is_list(Prop) ->
    wh_api:validate(Prop, ?NONCE_RESP_HEADERS, ?NONCE_RESP_VALUES, ?NONCE_RESP_TYPES);
nonce_resp_v(JObj) ->
    nonce_resp_v(wh_json:to_proplist(JObj)).


%%--------------------------------------------------------------------
%% @doc Authentication Request - see wiki
%% Takes proplist, creates JSON iolist or error
%% @end
%%--------------------------------------------------------------------
-spec authn_req(api_terms()) -> {'ok', iolist()} | {'error', string()}.
authn_req(Prop) when is_list(Prop) ->
        case authn_req_v(Prop) of
            true -> wh_api:build_message(Prop, ?AUTHN_REQ_HEADERS, ?OPTIONAL_AUTHN_REQ_HEADERS);
            false -> {error, "Proplist failed validation for authn_req"}
    end;
authn_req(JObj) ->
    authn_req(wh_json:to_proplist(JObj)).

-spec authn_req_v(api_terms()) -> boolean().
authn_req_v(Prop) when is_list(Prop) ->
    wh_api:validate(Prop, ?AUTHN_REQ_HEADERS, ?AUTHN_REQ_VALUES, ?AUTHN_REQ_TYPES);
authn_req_v(JObj) ->
    authn_req_v(wh_json:to_proplist(JObj)).


%%--------------------------------------------------------------------
%% @doc Authentication Response - see wiki
%% Takes proplist, creates JSON iolist or error
%% @end
%%--------------------------------------------------------------------
-spec authn_resp(api_terms()) -> {'ok', iolist()} | {'error', string()}.
authn_resp(Prop) when is_list(Prop) ->
    case authn_resp_v(Prop) of
        true -> wh_api:build_message(Prop, ?AUTHN_RESP_HEADERS, ?OPTIONAL_AUTHN_RESP_HEADERS);
        false -> {error, "Proplist failed validation for authn_resp"}
    end;
authn_resp(JObj) ->
    authn_resp(wh_json:to_proplist(JObj)).

-spec authn_resp_v(api_terms()) -> boolean().
authn_resp_v(Prop) when is_list(Prop) ->
    wh_api:validate(Prop, ?AUTHN_RESP_HEADERS, ?AUTHN_RESP_VALUES, ?AUTHN_RESP_TYPES);
authn_resp_v(JObj) ->
    authn_resp_v(wh_json:to_proplist(JObj)).

%%--------------------------------------------------------------------
%% @doc Authentication Error - see wiki
%% Takes proplist, creates JSON iolist or error
%% @end
%%--------------------------------------------------------------------
-spec error(api_terms()) -> {'ok', iolist()} | {'error', string()}.
error(Prop) when is_list(Prop) ->
    case error_v(Prop) of
        'true' -> wh_api:build_message(Prop, ?AUTHN_ERR_HEADERS, ?OPTIONAL_AUTHN_ERR_HEADERS);
        'false' -> {'error', "Proplist failed validation for authn_error"}
    end;
error(JObj) -> error(wh_json:to_proplist(JObj)).

-spec error_v(api_terms()) -> boolean().
error_v(Prop) when is_list(Prop) ->
    wh_api:validate(Prop, ?AUTHN_ERR_HEADERS, ?AUTHN_ERR_VALUES, ?AUTHN_ERR_TYPES);
error_v(JObj) -> error_v(wh_json:to_proplist(JObj)).

%%--------------------------------------------------------------------
%% @doc Authentication Success - see wiki
%% Takes proplist, creates JSON iolist or error
%% @end
%%--------------------------------------------------------------------
-spec success(api_terms()) -> {'ok', iolist()} | {'success', string()}.
success(Prop) when is_list(Prop) ->
    case success_v(Prop) of
        'true' -> wh_api:build_message(Prop, ?AUTHN_SUCCESS_HEADERS, ?OPTIONAL_AUTHN_SUCCESS_HEADERS);
        'false' -> {'success', "Proplist failed validation for authn_success"}
    end;
success(JObj) -> success(wh_json:to_proplist(JObj)).

-spec success_v(api_terms()) -> boolean().
success_v(Prop) when is_list(Prop) ->
    wh_api:validate(Prop, ?AUTHN_SUCCESS_HEADERS, ?AUTHN_SUCCESS_VALUES, ?AUTHN_SUCCESS_TYPES);
success_v(JObj) -> success_v(wh_json:to_proplist(JObj)).


%%--------------------------------------------------------------------
%% @doc GSM Route Request
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec route_req(api_terms()) ->
                 {'ok', iolist()} |
                 {'error', string()}.
route_req(Prop) when is_list(Prop) ->
    case route_req_v(Prop) of
        'true' -> wh_api:build_message(Prop, ?ROUTE_REQ_HEADERS, ?OPTIONAL_ROUTE_REQ_HEADERS);
        'false' -> {'error', "Proplist failed validation for route_req"}
    end;
route_req(JObj) -> route_req(wh_json:to_proplist(JObj)).

-spec route_req_v(api_terms()) -> boolean().
route_req_v(Prop) when is_list(Prop) ->
    wh_api:validate(Prop, ?ROUTE_REQ_HEADERS, ?ROUTE_REQ_VALUES, ?ROUTE_REQ_TYPES);
route_req_v(JObj) -> route_req_v(wh_json:to_proplist(JObj)).


%%--------------------------------------------------------------------
%% @doc GSM Pre Route Response
%% Takes proplist, creates JSON string or error
%% @end
%%--------------------------------------------------------------------
-spec route_resp(api_terms()) ->
                  {'ok', iolist()} |
                  {'error', string()}.
route_resp(Prop) when is_list(Prop) ->
    case route_resp_v(Prop) of
        'true' -> wh_api:build_message(Prop, ?ROUTE_RESP_HEADERS, ?OPTIONAL_ROUTE_RESP_HEADERS);
        'false' -> {'error', "Proplist failed validation for route_resp"}
    end;
route_resp(JObj) -> route_resp(wh_json:to_proplist(JObj)).

-spec route_resp_v(api_terms()) -> boolean().
route_resp_v(Prop) when is_list(Prop) ->
    wh_api:validate(Prop, ?ROUTE_RESP_HEADERS, ?ROUTE_RESP_VALUES, ?ROUTE_RESP_TYPES);
route_resp_v(JObj) -> route_resp_v(wh_json:to_proplist(JObj)).


-spec is_actionable_resp(api_terms()) -> boolean().
is_actionable_resp(Prop) when is_list(Prop) ->
    'true';
is_actionable_resp(JObj) ->
    is_actionable_resp(wh_json:to_proplist(JObj)).



%%--------------------------------------------------------------------
%% @doc Setup and tear down bindings for authn gen_listeners
%% @end
%%--------------------------------------------------------------------
-spec bind_q(ne_binary(), wh_proplist()) -> 'ok'.
bind_q(Q, Props) ->
    amqp_util:bind_q_to_callmgr(Q, ?KEY_GSM_REQ).

-spec unbind_q(ne_binary(), wh_proplist()) -> 'ok'.
unbind_q(Q, Props) ->
    amqp_util:unbind_q_from_callmgr(Q, ?KEY_GSM_REQ).

%%--------------------------------------------------------------------
%% @doc
%% declare the exchanges used by this API
%% @end
%%--------------------------------------------------------------------
-spec declare_exchanges() -> 'ok'.
declare_exchanges() ->
    amqp_util:callmgr_exchange().

%%--------------------------------------------------------------------
%% @doc Publish the JSON iolist() to the proper Exchange
%% @end
%%--------------------------------------------------------------------

-spec publish_nonce_req(api_terms()) -> 'ok'.
-spec publish_nonce_req(api_terms(), binary()) -> 'ok'.
publish_nonce_req(JObj) ->
    publish_nonce_req(JObj, ?DEFAULT_CONTENT_TYPE).
publish_nonce_req(Req, ContentType) ->
    {ok, Payload} = wh_api:prepare_api_payload(Req, ?NONCE_REQ_VALUES, fun ?MODULE:nonce_req/1),
    amqp_util:callmgr_publish(Payload, ContentType, ?KEY_GSM_REQ).

-spec publish_nonce_resp(ne_binary(), api_terms()) -> 'ok'.
-spec publish_nonce_resp(ne_binary(), api_terms(), binary()) -> 'ok'.
publish_nonce_resp(Queue, JObj) ->
    publish_nonce_resp(Queue, JObj, ?DEFAULT_CONTENT_TYPE).
publish_nonce_resp(Queue, Resp, ContentType) ->
    {ok, Payload} = wh_api:prepare_api_payload(Resp, ?NONCE_RESP_VALUES, fun nonce_resp/1),
    amqp_util:targeted_publish(Queue, Payload, ContentType).


-spec publish_authn_req(api_terms()) -> 'ok'.
-spec publish_authn_req(api_terms(), binary()) -> 'ok'.
publish_authn_req(JObj) ->
    publish_authn_req(JObj, ?DEFAULT_CONTENT_TYPE).
publish_authn_req(Req, ContentType) ->
    {ok, Payload} = wh_api:prepare_api_payload(Req, ?AUTHN_REQ_VALUES, fun ?MODULE:authn_req/1),
    amqp_util:callmgr_publish(Payload, ContentType, ?KEY_GSM_REQ).

-spec publish_authn_resp(ne_binary(), api_terms()) -> 'ok'.
-spec publish_authn_resp(ne_binary(), api_terms(), binary()) -> 'ok'.
publish_authn_resp(Queue, JObj) ->
    publish_authn_resp(Queue, JObj, ?DEFAULT_CONTENT_TYPE).
publish_authn_resp(Queue, Resp, ContentType) ->
    {ok, Payload} = wh_api:prepare_api_payload(Resp, ?AUTHN_RESP_VALUES, fun authn_resp/1),
    amqp_util:targeted_publish(Queue, Payload, ContentType).

-spec publish_error(ne_binary(), api_terms()) -> 'ok'.
-spec publish_error(ne_binary(), api_terms(), binary()) -> 'ok'.
publish_error(Queue, JObj) ->
    publish_error(Queue, JObj, ?DEFAULT_CONTENT_TYPE).
publish_error(Queue, Resp, ContentType) ->
    {ok, Payload} = wh_api:prepare_api_payload(Resp, ?AUTHN_ERR_VALUES, fun ?MODULE:error/1),
    amqp_util:targeted_publish(Queue, Payload, ContentType).

-spec publish_success(ne_binary(), api_terms()) -> 'ok'.
-spec publish_success(ne_binary(), api_terms(), binary()) -> 'ok'.
publish_success(Queue, JObj) ->
    publish_success(Queue, JObj, ?DEFAULT_CONTENT_TYPE).
publish_success(Queue, Resp, ContentType) ->
    {ok, Payload} = wh_api:prepare_api_payload(Resp, ?AUTHN_SUCCESS_VALUES, fun ?MODULE:success/1),
    amqp_util:targeted_publish(Queue, Payload, ContentType).


-spec publish_route_req(api_terms()) -> 'ok'.
-spec publish_route_req(api_terms(), binary()) -> 'ok'.
publish_route_req(JObj) ->
    publish_route_req(JObj, ?DEFAULT_CONTENT_TYPE).
publish_route_req(Req, ContentType) ->
    {ok, Payload} = wh_api:prepare_api_payload(Req, ?ROUTE_REQ_VALUES, fun ?MODULE:route_req/1),
    amqp_util:callmgr_publish(Payload, ContentType, ?KEY_GSM_REQ).

-spec publish_route_resp(ne_binary(), api_terms()) -> 'ok'.
-spec publish_route_resp(ne_binary(), api_terms(), binary()) -> 'ok'.
publish_route_resp(Queue, JObj) ->
    publish_route_resp(Queue, JObj, ?DEFAULT_CONTENT_TYPE).
publish_route_resp(Queue, Resp, ContentType) ->
    {ok, Payload} = wh_api:prepare_api_payload(Resp, ?ROUTE_RESP_VALUES, fun route_resp/1),
    amqp_util:targeted_publish(Queue, Payload, ContentType).


