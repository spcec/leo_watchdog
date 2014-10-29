%%======================================================================
%%
%% Leo Watchdog
%%
%% Copyright (c) 2012-2014 Rakuten, Inc.
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
%% @doc leo_watchdog for 'rex' process
%% @reference
%% @end
%%======================================================================
-module(leo_watchdog_rex).

-author('Yosuke Hara').

-behaviour(leo_watchdog_behaviour).

-include("leo_watchdog.hrl").
-include_lib("eunit/include/eunit.hrl").

%% API
-export([start_link/2,
         stop/0]).

%% Callback
-export([handle_call/2,
         handle_fail/2]).

-define(PROP_MAX_MEM_CAPACITY, 'max_memory_capacity').
-define(DEF_MEM_CAPACITY, 33554432).


%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------
%% @doc Start the server
-spec(start_link(MaxMemCapacity, IntervalTime) ->
             {ok,Pid} | ignore | {error,Error} when MaxMemCapacity::pos_integer(),
                                                    IntervalTime::pos_integer(),
                                                    Pid::pid(),
                                                    Error::{already_started,Pid} | term()).
start_link(MaxMemCapacity, IntervalTime) ->
    leo_watchdog:start_link(?MODULE, ?MODULE,
                            [{?PROP_MAX_MEM_CAPACITY, MaxMemCapacity}],
                            IntervalTime).


%% @doc Stop the server
-spec(stop() ->
             ok).
stop() ->
    leo_watchdog:stop(?MODULE).


%%--------------------------------------------------------------------
%% Callback
%%--------------------------------------------------------------------
%% @dog Call execution of the watchdog
-spec(handle_call(Id, State) ->
             ok | {error,Error} when Id::atom(),
                                     State::[{atom(), any()}],
                                     Error::any()).
handle_call(_Id, State) ->
    MemCapacity = leo_misc:get_value(?PROP_MAX_MEM_CAPACITY,
                                     State, ?DEF_MEM_CAPACITY),
    case whereis(rex) of
        undefined ->
            {{error, not_running}, State};
        Pid ->
            BinaryMem = erlang:memory(binary),
            case (BinaryMem >= MemCapacity) of
                true ->
                    erlang:garbage_collect(Pid);
                false ->
                    void
            end,
            {ok, State}
    end.


%% @dog Call execution failed
-spec(handle_fail(Id, Cause) ->
             ok | {error,Error} when Id::atom(),
                                     Cause::any(),
                                     Error::any()).
handle_fail(_Id,_Cause) ->
    ok.