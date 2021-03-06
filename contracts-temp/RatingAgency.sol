pragma solidity ^0.4.19;

import "./AnalystRegistry.sol";

contract RatingAgency {
    uint8 constant VERSION_MAJOR = 0;
    uint8 constant VERSION_MINOR = 9;
    
    uint constant DAY = 86400;
    uint16 constant CYCLES_AHEAD = 4; // number to keep ahead of the present
    uint constant ZERO_BASE_TIME = 1514764800;// 1536796800; // e.g. jan 1 2018
    uint8 constant CYCLE_FRACTIONS = 4; // affects overlap of cycles, etc.
    uint constant CYCLE_PERIOD =  DAY * 28; // e.g. 4 weeks
    //uint constant ACTIVE_TIME = 86400 * 28;
    //uint constant SCHEDULE_TIME = 86400 * 4; // 4 days before round activates
    // new timings by cycle fraction
    uint8 constant CYCLE_SCHEDULE = 7; // e.g. 1/7 of CYCLE_PERIOD
    uint8 constant CYCLE_BRIEF_DUE = 4; 
    uint8 constant CYCLE_SURVEY_DUE = 4;
    //uint constant BRIEF_DUE_TIME = 86400 * 7;
    //uint constant SURVEY_DUE_TIME = 86400 * 7;
    
    uint8 constant JURY_SIZE = 6; /// target jury size
    uint8 constant JURISTS_MIN = 2; // min jurists for a round
    uint16 constant ROUND_VALUE_DEFAULT = 100;
    
    //uint16 constant REPUTATION_LEAD = 12;
    function cycleFTime( uint8 frac ) public view returns ( uint ) { // cycle fraction time
        return ( cycle_period / frac );
    }
    // statuses
    uint8 constant NONE = 0;
    uint8 constant PENDING = 1;
    uint8 constant SCHEDULED = 2;
    uint8 constant ACTIVE = 3;
    uint8 constant FINISHED = 4;
    uint8 constant CANCELLED = 5;
    uint8 constant AVAILABLE = 6;
    uint8 constant CONFIRMED = 7;
    uint8 constant ASSIGNED = 8;
    uint8 constant SCHEDULED_LEAD = 9;
    uint8 constant SCHEDULED_JURIST = 10;
    uint8 constant BRIEF_DUE = 11;
    uint8 constant BRIEF_SUBMITTED = 12;
    uint8 constant FIRST_SURVEY_DUE = 13;
    uint8 constant FIRST_SURVEY_SUBMITTED = 14;
    uint8 constant SECOND_SURVEY_DUE = 15;
    uint8 constant SECOND_SURVEY_SUBMITTED = 16;
    uint8 constant ROUND_TALLIED = 17;
    uint8 constant DISQUALIFIED = 18;

    uint public lasttime;
    uint public time;
    uint public cycle_period;
    
    AnalystRegistry registry;

    struct CoveredToken {
      // rules:
      address token_addr;
  //    uint timestart;
      uint timeperiod;
      address representative;
    }
    mapping( uint32 => CoveredToken) covered_tokens;
    uint32 public num_tokens = 0;


    struct CycleAnalystStatus {
        uint8 num_volunteers;
        uint8 num_confirms;
        uint8 num_rounds;
        bytes32 rounds;
    }
    struct CycleAnalyst {
        uint32 analyst; 
        CycleAnalystStatus[2] analyst_status; // 0 for lead, 1 for jurist 
    }
    /* Cycles are the discreet periods when groups of tokens are run as Rounds */
    struct CycleRoleStatus {    // 0 lead, 1 jurist
        //uint16 num_volunteers;
        uint16 num_availables;    // i.e. confirmed
        uint16 num_assigns;
        mapping ( uint16 => uint16 ) availables;  // mapping analyst in-cycle ref to num entries
    }
    struct Cycle {
        uint timestart;
        uint period;
        uint8 stat;
        CycleRoleStatus[2] statuses;
        mapping ( uint16 => CycleAnalyst ) analysts;
        uint16 num_analysts;
    }
    mapping ( uint16 => Cycle ) cycles;
    uint16 public num_cycles = 0;

    struct RoundBrief {
        uint upload_time;
        bytes32 filehash;
    }
    struct RoundAnalyst {
        uint32 analyst;
        uint8 stat;
    }
    struct RoundSurvey {
        bytes32 answers;  // 1-5, qualitatives at 24,25, qualitatives at
        byte qualitatives; // yes / no
        uint8 recommendation; // 1-10
        bytes32 comment;
    }

    struct Round {
        uint16 cycle;
        uint32 covered_token;
        uint16 value; // value of the round in veva token
        uint8 stat;
        address representative;
        uint8 num_analysts;

        bytes32 avg_answer;
        uint8 r1_avg;  // scaled 0->100
        uint8 r2_avg;
        uint8 sways;
        uint8 winner;

        mapping ( uint8 => RoundBrief ) briefs; // submitted briefs... 0 is bull, 1 is bear
        mapping ( uint8 => RoundAnalyst ) analysts;
        mapping ( uint8 => RoundSurvey[2] ) surveys;     // 0 for pre, 1 for post
    }
    mapping ( uint16 => Round ) rounds;
    uint16 public num_rounds = 0;

    mapping ( uint16 => uint16 ) rounds_scheduled; // scheduled rounds by id
    mapping ( uint16 => uint16 ) rounds_active;
    //uint16 public num_rounds_scheduled = 0;
    uint16 public num_rounds_active = 0;

    address public registryAddress;

    /**
     * test data
    */
    address constant testregistry1 = 0x963d2928ca9f0969e626ab27d57067222e6fab81;
    address[16] live_tokens = [
        0x86fa049857e0209aa7d9e616f7eb3b3b78ecfdb0, //EOS
        0xf230b790e05390fc8295f4d3f60332c93bed42e2, // Tronix
        0xd850942ef8811f2a866692a623011bde52a462c1, // VeChain
        0xd26114cd6ee289accf82350c8d8487fedb8a0c07, // OMG
        0xb5a5f22694352c15b00323844ad545abb2b11028, // Icon
        0xb8c77482e45f1f44de1745f52c74426c631bdd52, // BnB
        0xe0b7927c4af23765cb51314a0e0521a9645f0e2a, // Digix
        0xd4fa1460f537bb9085d22c7bccb5dd450ef28e3a, // Populous
        0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2, // Maker
        0x744d70fdbe2ba4cf95131626614a1763df805b9e, // status
        0x168296bb09e24a88805cb9c33356536b980d3fc5, // RHOC
        0xe94327d07fc17907b4db788e5adf2ed424addff6,  // Reputation
        0x5ca9a71b1d01849c0a95490cc00559717fcf0d1d, // Aeternity
        0xcb97e65f07da24d46bcdd078ebebd7c6e6e3d750, // Byteom
        0xb7cb1c96db6b22b0d3d9536e0108d062bd488f74, // Walton
        0x4ceda7906a5ed2179785cd3a40a69ee8bc99c466 // Aeon
    ];

    function bootstrapTokens( ) public {
        for ( uint i = 0; i < live_tokens.length; i++ ) {
            tokenCover( live_tokens[i], 0 );
        }
    }

    /**
     * Constructor
    */
    function RatingAgency( address _registry, uint _period ) public {
        lasttime = ZERO_BASE_TIME;
        cycle_period = _period == 0 ? CYCLE_PERIOD : _period;

        if ( _registry == 0 ) _registry = testregistry1;
        registryAddress = _registry;
        registry = AnalystRegistry( _registry );
        registry.update( lasttime );

        cycleExtend( lasttime, 0 ); // bootstrap cycles
        bootstrapTokens( );
    }


    /*
     *   Token methods
    */

    event TokenAdd( uint32, address);
    function tokenCover( address _tokenContract, uint _timeperiod ) public {  // only specify period if different
        covered_tokens[ num_tokens ] = CoveredToken( _tokenContract, _timeperiod, msg.sender );
        TokenAdd( num_tokens, _tokenContract );
        num_tokens++;
    }

    function tokenInfo( uint32 _idx ) public view returns ( uint32, address ){
        return ( _idx, covered_tokens[ _idx ].token_addr );
    }

    /*
     ***   Round Cycler  ***
    */

    function cycleAnalystRef( uint16 _cycle, uint32 _analyst ) public view returns ( uint16 ref ){
        Cycle storage cycle = cycles[ _cycle ];
        for ( uint16 i = 0; i < cycle.num_analysts; i++ )
            if ( cycle.analysts[ i ].analyst == _analyst ) return i;
        return 0xffff;
    }

    function cycleAnalystInfo( uint16 _cycle, uint32 _analyst ) public view returns ( 
        uint16 analyst_ref,
        uint8, uint8, uint8, bytes32,
        uint8, uint8, uint8, bytes32
    ) {
        Cycle storage cycle = cycles[ _cycle ];
        uint16 ref = cycleAnalystRef( _cycle, _analyst );
        CycleAnalyst storage ca = cycle.analysts[ ref ]; 
        return (
            ref,
            ca.analyst_status[0].num_volunteers, ca.analyst_status[0].num_confirms, 
            ca.analyst_status[0].num_rounds, ca.analyst_status[0].rounds,
            ca.analyst_status[1].num_volunteers, ca.analyst_status[1].num_confirms,
            ca.analyst_status[1].num_rounds, ca.analyst_status[1].rounds            
        );
    }
  
    event CycleActivated( uint16 _cycle, uint time, uint16 num_rounds );
    function cycleActivate( uint16 _cycle ) public returns ( bool activated ) {
        Cycle storage c = cycles[ _cycle ];
        if ( c.stat == ACTIVE ) return false;
        c.stat = ACTIVE; 
        uint16 cyc4 = _cycle % CYCLE_FRACTIONS; // e.g. 0--3
        for ( uint16 i = 0; i < num_tokens; i++ ) {
            if ( !cycleRoundCanCreate( _cycle ) ) break; // stop cycle when out of availables
            if ( i % CYCLE_FRACTIONS == cyc4 ) // e.g. every 4th token at this particular timeperiod
                roundActivate( _cycle, i );
        }
        CycleActivated( _cycle, time, i );
        return true;
    }

    // for iterating through availabilities, i.e. getting a single one by availability reference
    function cycleAvailability( uint16 _cycle, uint8 _role, uint16 _ref_avail ) public view returns ( 
        uint32, uint16, uint8, uint16 
    ) {
        Cycle storage cycle = cycles[ _cycle ];
        uint16 ref = cycle.statuses[ _role ].availables[ _ref_avail ];
        return ( 
            cycle.analysts[ ref ].analyst, 
            ref, 
            cycle.analysts[ ref ].analyst_status[ _role ].num_confirms,
            cycle.statuses[ _role ].num_availables
        );
    }

    function cycleAvailabilityReduce( uint16 _cycle, uint8 _role, uint16 _ref_avail ) public {
        Cycle storage cycle = cycles[ _cycle ];
        CycleRoleStatus storage cs = cycle.statuses[ _role ];
        uint16 ref = cs.availables[ _ref_avail ];
        CycleAnalystStatus storage cas = cycle.analysts[ ref ].analyst_status[ _role ];
        
        if ( --cas.num_confirms == 0 ) { // remove from avail list
            cs.num_availables--;
            for( uint16 i = _ref_avail; i < cs.num_availables; i++ ) 
                cs.availables[ i ] = cs.availables[ i + 1 ];
        }
    }

    function cycleAvailabilityRef( uint16 _cycle, uint8 _role, uint16 _ref ) public view returns ( uint16 ) {
        CycleRoleStatus storage cs = cycles[ _cycle ].statuses[ _role ];
        for (uint16 i = 0; i < cs.num_availables; i++ ){
            if ( cs.availables[ i ] == _ref ) return i;
        }
        return 0xffff;
    }
    
    event CycleConfirmed( uint16 cycle, uint32 analyst, uint8 role, uint16 ref_avail, uint16 cs_num_availables, uint8 num_volunteers, uint8 num_confirms );
    function cycleConfirm( uint16 _cycle, uint32 _analyst, uint8 _role ) public {
        Cycle storage cycle = cycles[ _cycle ];
        uint16 ref = cycleAnalystRef( _cycle, _analyst );
        require( ref != 0xffff );
        uint8 num_confirms = ++cycle.analysts[ ref ].analyst_status[ _role ].num_confirms;
        uint8 num_volunteers = --cycle.analysts[ ref ].analyst_status[ _role ].num_volunteers;
        
        CycleRoleStatus storage cs = cycle.statuses[ _role ];
        uint16 ref_avail = cycleAvailabilityRef( _cycle, _role, ref );
        if ( ref_avail == 0xffff ) {
            ref_avail = cs.num_availables++;
            cs.availables[ ref_avail ] = ref;
        }
        //cs.num_volunteers--;
        CycleConfirmed( _cycle, _analyst, _role, ref_avail, cs.num_availables, num_volunteers, num_confirms );
    }
        
    event CycleAdded( uint16 cycle );    
    // Create future cycles
    function cycleExtend( uint _timenow, uint8 _num ) public { // can make internal, public for now, testing
        uint timenow = _timenow == 0 ? ZERO_BASE_TIME : _timenow;
        uint16 num_target = _num == 0 ? cycleIdx( timenow ) + CYCLES_AHEAD : _num;
        for ( uint16 i = num_cycles; i < num_target; i++ ) {
            cycles[i].timestart = cycleTime( i );
            cycles[i].period = cycle_period;
            cycles[i].stat = NONE;
            CycleAdded( i );
        }
        num_cycles = num_target;
    }
    
    event CycleFinished( uint16 cycle, uint16 cycle_finished, uint time );
    function cycleFinish( uint16 _cycle ) public { // finish any previous cycles
        for ( uint16 i = 0; i < num_rounds_active; i++ ) {
            uint16 round = rounds_active[ i ];
            Cycle storage c = cycles[ rounds[ round ].cycle ];
            if ( c.timestart + c.period <= time )
                roundFinish( round );
        }
        for ( i = 0; i < _cycle; i++ ){ // deactivate any past cycles
            if (cycles[ i ].stat == ACTIVE) cycles[ i ].stat = FINISHED;
            CycleFinished( _cycle, i, time );
        }
    }

    function cycleIdx( uint _time ) public view returns ( uint16 ) {
        return( _time <= ZERO_BASE_TIME ?
            0 : uint16( 4 * ( _time - ZERO_BASE_TIME ) / cycle_period ) );
    }

    function cycleInfo ( uint16 _cycle ) public view returns ( 
        uint16, uint, uint, uint8, 
        uint16, uint16, 
        uint16, uint16 
    ) {
        Cycle storage cycle = cycles[ _cycle ];
        return (
            _cycle, cycleTime( _cycle ), cycle.period, cycle.stat,
            cycle.statuses[0].num_availables, cycle.statuses[0].num_assigns,
            cycle.statuses[1].num_availables, cycle.statuses[1].num_assigns
        );
    }

    function cycleRoundCanCreate( uint16 _cycle ) public view returns( bool ){ // make internal, public for test
        Cycle storage cycle = cycles[ _cycle ];
        return ( cycle.statuses[ 0 ].num_availables > 1 && cycle.statuses[ 1 ].num_availables >= JURISTS_MIN );
    }
    
    function cycleSelect( uint16 _cycle, uint8 _role ) public view returns ( uint16 ref_avail, uint16 ref ) {  // returns local reference to an available analyst
        Cycle storage cycle = cycles[_cycle];
        CycleRoleStatus storage cs = cycle.statuses[ _role ];
        require( cs.num_availables > 0 );
        ref_avail = cs.num_availables == 1 ? cs.availables[0] : uint16( randomIdx( cs.availables[ 0 ], cs.num_availables ) );
        ref = cs.availables[ ref_avail ];
    }

    // start time for a cycle
    function cycleTime( uint16 _idx ) public view returns ( uint ){
        return cycle_period * _idx / 4 + ZERO_BASE_TIME;    // cycles offset
    }

    event CycleVolunteer( uint16 cycle, uint32 analyst, uint8 role, uint8 num_volunteers );
    function cycleVolunteer( uint16 _cycle, uint32 _analyst, uint8 _role ) public {
        Cycle storage cycle = cycles[ _cycle ];
        uint16 ref = cycleAnalystRef( _cycle, _analyst );
        if (ref == 0xffff) {
            ref = cycle.num_analysts++;
            cycle.analysts[ ref ].analyst = _analyst;
        }
        //cycle.statuses[ _role ].num_volunteers++; 
        uint8 num_volunteers = ++cycle.analysts[ ref ].analyst_status[ _role ].num_volunteers;
        CycleVolunteer( _cycle, _analyst, _role, num_volunteers );
    }

    /*
     ***** Round ****
    */

    event RoundActivated( uint16 _cycle, uint16 _round, uint16 num_rounds_active, uint8 num_analysts );
    function roundActivate( uint16 _cycle, uint32 _token ) public returns ( uint16 ){ 
        uint16 round = num_rounds++;
        Round storage r     = rounds[ round ];    
        r.cycle             = _cycle;
        r.covered_token     = _token;    
        r.value             = ROUND_VALUE_DEFAULT;
        r.stat              = ACTIVE;
        r.representative    = msg.sender;
        rounds_active[ num_rounds_active++ ] = round;
        roundPopulate( _cycle, round );
        for (uint8 a = 0; a < r.num_analysts; a++ ) {
            RoundAnalyst storage ra = r.analysts[ a ];
            ra.stat = a<2 ? BRIEF_DUE: FIRST_SURVEY_DUE;
            //registry.activateRound( ra.analyst_id, round );
        }       
        RoundActivated( r.cycle, round, num_rounds_active, r.num_analysts );
    }
    
    function roundAnalyst( uint16 _round, uint32 _analyst ) public view returns (uint8, uint8) {
        Round storage round = rounds[_round];
        for ( uint8 i=0; i < round.num_analysts; i++){
            if ( round.analysts[ i ].analyst == _analyst )
                return( i, round.analysts[ i ].stat ); 
        }
        return ( 0, NONE );    // not found, no status
    }
    function roundAnalystId( uint16 _round, uint8 _inround_analyst) public view returns (uint32) {
        return ( rounds[_round].analysts[ _inround_analyst ].analyst );        
    }

    function roundBriefs( uint16 _round ) public view returns ( uint, bytes32, uint, bytes32 ){
        Round storage round = rounds[ _round ];
        return (
            round.briefs[ 0 ].upload_time, round.briefs[ 0 ].filehash, 
            round.briefs[ 1 ].upload_time,round.briefs[ 1 ].filehash 
        );
    }
    event BriefSubmitted( uint16 _round, uint8 _analyst, bytes32 _file );
    function roundBriefSubmit( uint16 _round, uint8 _analyst, bytes32 _file ) public {
        Round storage round = rounds[ _round ];
        round.briefs[ _analyst ] = RoundBrief( lasttime, _file);
        round.analysts[ _analyst ].stat = BRIEF_SUBMITTED;
        BriefSubmitted( _round, _analyst, _file );
    }

    event RoundFinished( uint16 _cycle, uint16 _round, uint16 num_rounds_active );
    function roundFinish( uint16 _round ) public {
        rounds[ _round ].stat = FINISHED;
        roundTally( _round );
        for (uint16 i = 0; i < num_rounds_active; i++){ // remove from active rounds
            if ( rounds_active[i] == _round ) {
                num_rounds_active--;
                for (uint16 j = i; j < num_rounds_active; j++)
                    rounds_active[ j ] = rounds_active[ j + 1 ];
                break;
            }
        }
        RoundFinished( rounds[ _round ].cycle, _round, num_rounds_active );
    }

    function roundInfo ( uint16 _round ) public view returns (
        uint16, uint16, uint32, uint16, uint8, uint8
    ) {
        Round storage round = rounds[ _round ];
        return (
            _round, round.cycle, round.covered_token,
            round.value, round.stat, round.num_analysts
        );
    }

    // assign available analysts from the cycle into the round
    event RoundPopulated( uint16 _cycle, uint16 _round, uint8 num_analysts, uint8 num_leads );
    //event RoundAnalystAdded( uint16 _cycle, uint16 _round, uint32 _analyst);
    function roundPopulate( uint16 _cycle, uint16 _round ) public {
        uint16 ref;
        uint16 ref_avail;
        uint32 analyst;
        Round storage round = rounds[ _round ];
        Cycle storage cycle = cycles[ _cycle ];
        uint8 num_jurists = min_jury( JURY_SIZE, cycles[ _cycle ].statuses[ 1 ].num_availables );

        for ( uint16 i = 0; i < 2+num_jurists; i++ ) {
            uint8 role = i < 2 ? 0 : 1; // first two are bull/bear leads
            ( ref_avail, ref ) = cycleSelect( _cycle, role );  
            cycleAvailabilityReduce( _cycle, role, ref_avail );
            CycleAnalystStatus storage cas = cycle.analysts[ ref ].analyst_status[ role ];
            cas.rounds = uint16InserttoBytes32( cas.rounds, _round, cas.num_rounds++ );
    
            RoundAnalyst storage ra = round.analysts[ round.num_analysts++ ];
            ra.analyst = analyst; 
            ra.stat = i < 2 ? SCHEDULED_LEAD: SCHEDULED_JURIST;
            //RoundAnalystAdded( _cycle, _round, analyst );
            registry.activateRound( analyst, _round );
        }
        RoundPopulated( _cycle, _round, round.num_analysts, 2 );
    }
    
    function roundSummary ( uint16 _round ) public view returns (
        bytes32, uint8, uint8, uint8, uint8
    ) {
        Round storage round = rounds[ _round ];
        return (
            round.avg_answer,
            round.r1_avg,  // scaled 0->100
            round.r2_avg,
            round.sways,
            round.winner
        );
    }

    /* get next 16 rounds */
    function roundsForToken ( uint16 _token, uint16 startAt ) public view returns (uint16 _numFound, uint16[16] _rounds){
        _numFound = 0;
        for (uint16 i = 0; i < num_rounds; i++){
            if (rounds[i].covered_token == _token){
                if (_numFound >= startAt) {
                    _rounds[_numFound - startAt] = i;
                }
                _numFound++;
                if (_numFound == 16 + startAt) break;
            }
        }
        _numFound = _numFound % 16;
    }
        
    event SurveySubmitted( uint16 _round, uint32 _analyst, uint8 _idx, bytes32 _answers, byte _qualitatives, uint8 _recommendation );
    function roundSurveySubmit(
        uint16 _round,
        uint8 _analyst, // analyst by round index
        uint8 _idx,              // pre (0), or post (1)
        bytes32 _answers,
        byte _qualitatives,
        uint8 _recommendation,
        bytes32 _comment
    ) public {
        Round storage round = rounds[ _round ];
        // do some checks here
        RoundAnalyst storage analyst = round.analysts[ _analyst ];

        //require( _idx==0 && analyst.stat == FIRST_SURVEY_DUE || _idx==1 && analyst.stat == SECOND_SURVEY_DUE );
        round.surveys[_analyst][_idx] = RoundSurvey( _answers, _qualitatives, _recommendation, _comment );
        analyst.stat = _idx == 0 ? FIRST_SURVEY_SUBMITTED : SECOND_SURVEY_SUBMITTED;
        SurveySubmitted( _round, _analyst, _idx, _answers, _qualitatives, _recommendation );
    }

    event TallyLog( uint16 round, uint8 analyst, uint8 recommendation);
    event TallyWin( uint16 round, uint8 winner );
    function roundTally( uint16 _round ) public {
        Round storage round = rounds[ _round ];
        /* sway of answers , not used right now
        int[] memory sway = new int[](32);
        for (uint i; i < 32; i++) {
            for (uint8 a; a < round.num_analysts; a++) {
                sway[i] = ( sway[i] * int(i) + int(round.surveys[1][a].answers[i]) - int(round.surveys[0][a].answers[i]) ) / ( i+1 ) ;
            }
            round.avg_sway[ i ] = byte( sway[ i ] );
        }
        */
        uint8 n = 0;
        for ( uint8 aref = 2; aref < round.num_analysts; aref++ ) {
            TallyLog( _round, aref, round.surveys[aref][0].recommendation );
            TallyLog( _round, aref, round.surveys[aref][1].recommendation );

            //if (round.surveys[a][0] && round.surveys[a][1] ) {
                round.r1_avg = (round.r1_avg*n + 10*round.surveys[aref][0].recommendation) / (n+1);
                round.r2_avg = (round.r2_avg*n + 10*round.surveys[aref][1].recommendation) / (n+1);
                n++;

            //}
        }
        TallyLog( _round, 100, round.r1_avg );
        TallyLog( _round, 101, round.r2_avg );

        if ( round.r2_avg > round.r1_avg + 20) round.winner = 0;
        else if ( round.r2_avg < round.r1_avg - 20) round.winner = 1;
        else if ( round.r2_avg > 50 ) round.winner = 0;
        else round.winner = 1;

        // payoff in token and reputation, just leads for nowREWARD_ROUND_TOKENS_LOSER
        for ( uint8 i = 0; i < 2; i++ )
            registry.rewardLead( round.analysts[i].analyst, _round, round.value, int8(round.winner == i ? 1 : 0) );
        for ( i = 2; i < round.num_analysts; i++ )
            registry.rewardJurist( round.analysts[ i ].analyst, _round, round.value, 0 ); // for now, every jurist is a winner, pending tally above

        TallyWin( _round, round.winner );

    }

    // cron
    event Cron( uint lasttime, uint timestamp, uint16 cycle );
    function cron( uint _time ) public {
        time = _time == 0 ? ZERO_BASE_TIME : _time; // e.g. block.timestamp
        uint16 cycle = cycleIdx( time );

        Cron( lasttime, time, cycle );

        if ( time < lasttime ) return; // don't repeat for times already run
        registry.update( time ); // keep time in sync

        cycleExtend( time, 0 ); // start new cycles if needed

        cycleFinish( cycle );

        cycleActivate( cycle ); 

        lasttime = time;
    }

    /*
     *  utilities
    */
    function uint16InserttoBytes32( bytes32 _bytes, uint16 _ui, uint8 _position ) public pure returns ( bytes32 ){
        return bytes32( ( bytes32( _ui ) << ( (15 - _position) * 16 ) ) | _bytes );
    }
    function bytesToBytes32(bytes b, uint offset) internal pure returns (bytes32 out) {
        for (uint i = 0; i < 32; i++)
            out |= bytes32(b[offset + i] & 0xFF) >> (i * 8);
    }
    function min_jury( uint8 a, uint16 b ) internal pure returns ( uint8 min ) { 
        min = uint16(a) < b ? a : uint8(b); 
    }
    /* Generate random number 0 to n-1 (based on last block hash) */
    function randomIdx(uint seed, uint n) public constant returns (uint randomNumber) {
        return(uint(keccak256(block.blockhash(block.number-1), seed ))%(n-1));
    }
    
    /* 
     *  Test code
    */
    
    // volunteer and confirm everybody to cycle
    // analysts with Lead capability volunteer twice as lead and jury
    function cycleGenerateAvailabilities( uint16 _cycle ) public {
        require( cycles[ _cycle ].stat == NONE );    // only for inactive cycles
        uint32 num_analysts = registry.num_analysts();
        for ( uint32 analyst = 0; analyst < num_analysts; analyst++ ) {
            bool isLead = registry.isLead( analyst );
            for ( uint8 role = 0; role < 2; role++ ) {
                if ( role == 0 && !isLead ) continue;
                cycleVolunteer( _cycle, analyst, role );
                cycleConfirm( _cycle, analyst, role );
            }
        }
    }

    // generate more availabilities for all current and future cycles
    /*
    function cycleGenerateAllAvailabilities() public {
        for ( uint16 cycleId = cycleIdx( lasttime ); cycleId < num_cycles; cycleId++ ) 
            cycleGenerateAvailabilities( cycleId );
    }
    */





}





contract Survey {  // "read-only" survey questions
  uint16 public version = 1;
  uint16 num_questions = 24;  // num questions not including final
  string public questions; // ipfs hash for questions json
  function Survey(string _questionsfile) public {
      questions = _questionsfile;
  }
}
