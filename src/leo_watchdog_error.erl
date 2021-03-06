%%======================================================================
%%
%% Leo Watchdog
%%
%% Copyright (c) 2012-2017 Rakuten, Inc.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%%======================================================================
-module(leo_watchdog_error).

-author('Yosuke Hara').

-behaviour(leo_watchdog_behaviour).

-include("leo_watchdog.hrl").
-include_lib("eunit/include/eunit.hrl").

%% API
-export([start_link/2,
         update_property/3,
         stop/0,
         state/0
        ]).

%% Callback
-export([init/1,
         handle_call/2,
         handle_fail/2]).

-record(state, {
          threshold_num_of_errors :: non_neg_integer(),
          interval = timer:seconds(1) :: non_neg_integer()
         }).


%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------
%% @doc Start the server
-spec(start_link(ThresholdNumOfErrors, Interval) ->
             {ok,Pid} |
             ignore |
             {error,Error} when ThresholdNumOfErrors::non_neg_integer(),
                                Interval::pos_integer(),
                                Pid::pid(),
                                Error::{already_started,Pid} | term()).
start_link(ThresholdNumOfErrors, Interval) ->
    State = #state{threshold_num_of_errors = ThresholdNumOfErrors,
                   interval = Interval},
    leo_watchdog:start_link(?MODULE, ?MODULE, State, Interval).


%% @doc Stop the server
-spec(stop() ->
             ok).
stop() ->
    leo_watchdog:stop(?MODULE).


%% @doc Retrieves state of the watchdog
-spec(state() ->
             {ok, State} when State::[{atom(), any()}]).
state() ->
    case ets:lookup(?MODULE, state) of
        [] ->
            not_found;
        [State|_] ->
            State_1 = lists:zip(record_info(fields, state),tl(tuple_to_list(State))),
            {ok, State_1}
    end.


%%--------------------------------------------------------------------
%% Callback
%%--------------------------------------------------------------------
%% @doc Initialize this process
-spec(init(State) ->
             ok | {error, Cause} when State::any(),
                                      Cause::any()).
init(_State) ->
    ok.


%% @doc Update the item's value
-spec(update_property(Item, Value, State) ->
             #state{} when Item::atom(),
                           Value::any(),
                           State::#state{}).
update_property(_,_, State) ->
    State.


%% @doc Call execution of the watchdog
-spec(handle_call(Id, State) ->
             {ok, State} |
             {{error,Error}, State} when Id::atom(),
                                         State::#state{},
                                         Error::any()).
handle_call(Id, #state{threshold_num_of_errors = ThresholdNumOfErrors} = State) ->
    {ok, {Count, SetErrors}} = leo_watchdog_collector:pull(),
    case (Count >= ThresholdNumOfErrors) of
        true ->
            Props = [{count, Count}, {errors, SetErrors}],
            error_logger:warning_msg("~p,~p,~p,~p~n",
                                     [{module, ?MODULE_STRING},
                                      {function, "handle_call/2"},{line, ?LINE},
                                      {body, [{triggered_watchdog, continuous_error}] ++ Props}]),
            catch elarm:raise(Id, ?WD_ITEM_ERRORS,
                              #watchdog_state{id = Id,
                                              level = ?WD_LEVEL_ERROR,
                                              src = ?WD_ITEM_ERRORS,
                                              props = Props});
        false ->
            catch elarm:clear(Id, ?WD_ITEM_ERRORS)
    end,
    {ok, State}.

%% @doc Call execution failed
-spec(handle_fail(Id, Cause) ->
             ok | {error,Error} when Id::atom(),
                                     Cause::any(),
                                     Error::any()).
handle_fail(_Id,_Cause) ->
    ok.


%%--------------------------------------------------------------------
%% Internal Function
%%--------------------------------------------------------------------
