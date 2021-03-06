// @flow weak

/* eslint no-console:0 */
/* eslint consistent-return:0 */
import moment               from 'moment'
import { getRoundInfo, getRoundAnalystInfo, getRoundsSummary, submitRound, submitRoundSurvey } from '../../services/API'
import { toHexString } from '../../services/utils'
import { fetchTokenData }  from './tokens'

import {
  REQUEST_ROUNDS_FINISHED,
  RECEIVED_ROUNDS_FINISHED,
  ERROR_ROUNDS_FINISHED,
  REQUEST_ROUND_INFO,
  RECEIVED_ROUND_INFO,
  ERROR_ROUND_INFO,
  SET_ROUND_INFO,
  REQUEST_ROUND_ANALYST_INFO,
  RECEIVED_ROUND_ANALYST_INFO,
  ERROR_ROUND_ANALYST_INFO,
  REQUEST_SURVEY_SUBMIT,
  RECEIVED_SURVEY_SUBMIT,
  ERROR_SURVEY_SUBMIT
} from './actionTypes'

const initialState = {
  isFetching: false,
  data:       [], // rounds
  time:       null
};

const rounds = (state = initialState, action) => {
  let s, i

  switch (action.type) {

  case REQUEST_ROUNDS_FINISHED:
    return { ...state, isFetching: action.isFetching, time: action.time }
  case RECEIVED_ROUNDS_FINISHED:
    return { ...state, isFetching: action.isFetching, data: [...action.data], time: action.time }
  case ERROR_ROUNDS_FINISHED:
    return { ...state, isFetching: action.isFetching, time: action.time }

  case REQUEST_ROUND_INFO:
    return { ...state, time: action.time }
  case RECEIVED_ROUND_INFO: 
  case SET_ROUND_INFO: 
    //console.log('round info action is',action)
    s = { data:[], ...state, time: action.time }
    i = s.data.findIndex( round => action.roundInfo.id == round.id ) //_.findIndex(s.data,['id',action.roundInfo.id])
    if (i==-1)
      s.data.push( action.roundInfo ) // add
    else
      s.data[i] = { ...s.data[i], ...action.roundInfo } // merge
    return s
    //return {...state, round: action.roundInfo, time: action.time }
  case ERROR_ROUND_INFO:
    return {...state, time: action.time }

  case REQUEST_ROUND_ANALYST_INFO:
    return { ...state, time: action.time }
  case RECEIVED_ROUND_ANALYST_INFO:
    //console.log('round analyst action is',action) 
    s = { data:[], ...state, time: action.time }
    // i = _.findIndex(s.data,['id',action.roundAnalystInfo.id])
    i = s.data.findIndex( round => round.id == action.roundAnalystInfo.id )
    if ( i==-1 )
      s.data.push( action.roundAnalystInfo ) // add
    else
      s.data[i] = {...s.data[i], ...action.roundAnalystInfo} // merge    
    return s
  case ERROR_ROUND_ANALYST_INFO:
    return { ...state, time: action.time }

  default:
    return state;
  }
}
export default rounds

/*
export const fetchRoundsDataIfNeeded = () => {
  return (dispatch, getState) => {
    console.log('fetch rounds data if needed')
    if (shouldFetchRoundsData(getState())) {
      return dispatch(fetchRoundsData())
    }
  }
}

const fetchRoundsData = () => {
  const request = (time = moment().format()) => {
    return { type: REQUEST_ROUNDS_DATA, isFetching: true, time }
  }
  const success = (data, time = moment().format()) => {
    return { type: RECEIVED_ROUNDS_DATA, isFetching: false, data, time }
  }
  const failure = (time = moment().format()) => { 
    return { type: ERROR_ROUNDS_DATA, isFetching: false, time }
  }

  console.log('fetch rounds data')
  return dispatch => {
    dispatch(request())
      console.log('getting rounds data from api')
      getRoundsData()
      .then( data => dispatch(success(data)) )
      .catch( error => dispatch(failure(error)) )    
  }
}

const shouldFetchRoundsData = (state) => {
  return !state.rounds.isFetching
}

*/

export const setRoundInfo = ( roundInfo ) => dispatch => {
  dispatch(  { type: SET_ROUND_INFO, roundInfo, time: moment().format() } )
}

export const fetchRoundInfo = ( round, deep = false ) => {
  const request = (time = moment().format()) => {
    return { type: REQUEST_ROUND_INFO, time }
  }
  const success = (roundInfo, time = moment().format()) => {
    return { type: RECEIVED_ROUND_INFO, roundInfo, time }
  }
  const failure = (time = moment().format()) => {
    return { type: ERROR_ROUND_INFO, time }
  }
  return (dispatch, getState) => {
    const err = ( error ) => dispatch( failure( error ) )
    return new Promise( (resolve,reject) => {
      dispatch( request() )
      //console.log('getting round info',round)
      getRoundInfo(round).then( roundInfo => {
        //console.log('got round info for round',round)
        fetchTokenData( roundInfo.covered_token, false )( dispatch, getState ).then( ( tokenData ) => {
          //console.log(' got token data',tokenData)
          resolve( roundInfo )
          dispatch( success( roundInfo ) ) 
        }).catch( ( error ) => {
          reject( error )
        })
      }).catch( err ) 
    }) 
  }
}


export const fetchRoundsFinished = () => {
  const request = (time = moment().format()) => ( { type: REQUEST_ROUNDS_FINISHED, isFetching: true, time } )
  const success = (data, time = moment().format()) => ( { type: RECEIVED_ROUNDS_FINISHED, isFetching: false, data, time } )
  const failure = (time = moment().format()) => ( { type: ERROR_ROUNDS_FINISHED, isFetching: false, time } )
  //console.log('fetch rounds finished')
  return dispatch => {
    dispatch(request())
      //console.log('getting rounds data from api')
      getRoundsSummary()
      .then( data => dispatch(success(data)) )
      .catch( error => dispatch(failure(error)) )    
  }
}

const getUser = (state) => state.user.info ? state.user.info.id : 0

export const fetchRoundAnalystInfo = ( round, analyst = -1 ) => {
  const request = (time = moment().format()) => {
    return { type: REQUEST_ROUND_ANALYST_INFO, time }
  }
  const success = (roundAnalystInfo, time = moment().format()) => {
    return { type: RECEIVED_ROUND_ANALYST_INFO, roundAnalystInfo, time }
  }
  const failure = (time = moment().format()) => {
    return { type: ERROR_ROUND_ANALYST_INFO, time }
  }
  return ( dispatch, getState ) => {
    //console.log('fetch analyst info', round, analyst)
    dispatch( request() )
    //console.log('getting round analyst infor for user ',getState(),getUser(getState()))
    return getRoundAnalystInfo(round, analyst==-1 ? getUser(getState()) : analyst).then( roundAnalystInfo => {
      dispatch( success( roundAnalystInfo ) ) 
      return roundAnalystInfo
    })
    .catch( error => dispatch( failure(error) ) )
  }
}




/*        uint8 _analyst, // analyst by round index
        uint8 _idx,              // pre (0), or post (1)
        bytes32 _answers,
        byte _qualitatives,
        uint8 _recommendation,
        bytes32 _comment
    )
*/
export const submitSurvey = ( round, roundAnalyst, pre, answers ) => {
  const request = ( time = moment().format() ) => ( { type: REQUEST_SURVEY_SUBMIT, time } )
  const success = ( time = moment().format() ) => ( { type: RECEIVED_SURVEY_SUBMIT, time } )
  const failure = (time = moment().format()) => ( { type: ERROR_SURVEY_SUBMIT, time } )
  
  //console.log('submitSurvey action',round,roundAnalyst,pre,answers)
  let qualitatives = 0
  let recommendation = 0
  let comment = ""

  return (dispatch,getState) => {
    dispatch( request() )
    let answersB32 = toHexString( answers )
    //console.log('data',answers,'bytes32',answersB32)
    return submitRoundSurvey( round, roundAnalyst, answersB32, qualitatives, recommendation, comment, pre?0:1 )
    .then( result => {
      dispatch( success() ) 
      return fetchRoundAnalystInfo( round, roundAnalyst )( dispatch, getState )
    } )
    .catch( err => { 
      console.log('error submitting survey')
      return err
    })
  }
}

export const roundActions = {
  fetchRoundInfo,
  fetchRoundAnalystInfo,
  fetchRoundsFinished,
  submitSurvey
}
