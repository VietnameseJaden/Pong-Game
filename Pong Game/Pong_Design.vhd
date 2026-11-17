----------------------------------------------------------------------------------
-- Company: Kennesaw State University
-- Engineer: Jaden Nguyen, Jeffery Lin
-- 
-- Create Date: 10/27/2026 09:00:27 AM
-- Design Name: Lab4
-- Module Name: pong - Behavioral
-- Project Name: Ping Pong Game
-- Target Devices: 
-- Tool Versions: 
-- Description: Implements a two-player LED ping-pong game using a finite
--              state machine. Controls ball position, movement direction,
--              serving, hit detection, and scoring. Increases ball speed
--              after each point up to a set limit and outputs both player
--              scores for display. Ends the game when a player reaches
--              seven points and waits for reset.
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity pong is
  generic(
        CLOCK_PERIOD: time := 10 ns;
        SAMPLE_PERIOD: time := 2 ms;
        DEPTH: integer := 16;
        BYPASS_DEBOUNCE: boolean := false;
        LED_SPEED: integer := 25000000
    );
--  Port ( );
    port(
        clock: in std_logic;
        reset: in std_logic;
        P1En: in std_logic;
        P2En: in std_logic;
        winCount: in std_logic_vector(15 downto 0);
        P1win: out std_logic;
        P2win: out std_logic;
        LEDS: out std_logic_vector(15 downto 0);
        P1Ones: out std_logic_vector(3 downto 0);
        P1Tens: out std_logic_vector(3 downto 0);
        P2Ones: out std_logic_vector(3 downto 0);
        P2Tens: out std_logic_vector(3 downto 0)
        );
end pong;

architecture pong_ARCH of pong is
    constant ACTIVE: std_logic:= '1';
    -- Enable signal that drives the leds
    signal moveEn: std_logic;
    -- holds until player hits the ball
    signal holdMode: std_logic;
    signal directionMode: std_logic;
    signal P1winEn: std_logic;
    signal p2winEn: std_logic;
    signal position: integer range 0 to 15;
    signal P1miss: std_logic;
    signal P2miss: std_Logic;
    -- Enable signal to increment scores
    signal P2ScoreEn: std_logic;
    signal P1ScoreEn: std_logic;
    -- Max score is 99
    signal P1Score: integer range 0 to 99;
    signal P2Score: integer range 0 to 99;
    signal serveCount : integer := 0;
    signal winScore: integer range 0 to 15;
    -- calculate range needed for desired interval
    constant MAX: integer := (SAMPLE_PERIOD / CLOCK_PERIOD) - 1;
    -- number of samples that need to be different to register
    constant MIN_SAMPLES: integer := DEPTH * 3 / 4;
    -- sample
    signal sampleEn: std_logic;
    -- debounced signal for Player 1 (left)
    signal syncOut1: std_logic;
    -- debounced signal for Player 2 (right)
    signal syncOut2: std_logic; 
    -- ensures only Player 1 or Player 2 can hit the button
    signal P1Valid: std_logic;
    signal P2Valid: std_logic;
    -- Enable signal to increase LED speed
    signal incSpeedEn: std_logic;
    -- debounced signal to ensure no button holding can occur
    signal P1Button: std_logic;
    signal P2Button: std_logic;    
    -- signal to indicate when a player happens
    signal serveContinue: std_logic;     
    signal P1safeOutput: std_logic;
    signal P2safeOutput: std_logic;
    signal currentSpeed: integer range 0 to LED_SPEED; 
    type States_t is (P1_NEXT_SERVE, P2_NEXT_SERVE, P1MOVE_BUFFER, P2MOVE_BUFFER, MOVE_RIGHT, MOVE_LEFT, 
                    P1_HIT_DETECTION, P2_HIT_DETECTION, P1_MISS, P2_MISS,
                    SERVE_ALTERNATE, P_WIN);
                    
    signal currentState: States_t; 
    signal nextState: States_t;
    
   
    
begin
    -- sample raw signal to improve metastability
    -- in : (reset, clock) P1En
    -- out: P1safeOutput
    P1SYNC_CHAIN: process(reset, clock)
        variable unsafeOutput: std_logic;
    begin
        if (reset = ACTIVE) then
            P1safeOutput <= not ACTIVE;
            unsafeOutput := not ACTIVE;
    
        elsif rising_edge(clock) then
            P1safeOutput <= unsafeOutput;
            unsafeOutput := P1En;
        end if;
    end process P1SYNC_CHAIN;
   -- sample raw signal to synchronize and further debounce
   -- in : (reset, clock) P2En
   -- out: P2safeOutput
   P2SYNC_CHAIN: process(reset, clock)
        variable unsafeOutput: std_logic;
    begin
        if (reset = ACTIVE) then
            P2safeOutput <= not ACTIVE;
            unsafeOutput := not ACTIVE;
    
        elsif rising_edge(clock) then
            P2safeOutput <= unsafeOutput;
            unsafeOutput := P2En;
        end if;
    end process P2SYNC_CHAIN;
    -- Sampling rate for debouncing buttons
    -- in : (reset, clock) MAX
    -- out: sampleEn
    SAMPLE: process (reset, clock) is
    variable count: integer range 0 to MAX;
    begin
        if (reset = ACTIVE) then
        -- ready for next sample on reset
            sampleEn <= (not ACTIVE);
            count := 0;
        elsif rising_edge(clock) then
            sampleEn <= (not ACTIVE);
            -- sample on increased interval
            if (count < MAX) then
                -- increment counter
                count := count + 1;
            else
                -- overflow back to 0
                count := 0;
                sampleEn <= ACTIVE;
            end if;
        end if;
    end process;
    -- sample raw signal to synchronize and further debounce
    -- in : (reset, clock) sampleEn, P1safeOutput, syncOut1
    -- out: P1Button
    DEBOUNCE_LEFT: process (reset, clock) is
        variable previous1: std_logic_vector(DEPTH-1 downto 0);
        variable count1: integer range 0 to DEPTH;
        variable lastButton1: std_logic := '0';
    begin
        if (reset = ACTIVE) then
        -- clear to inactive on reset
            previous1 := (others => not ACTIVE);
            count1 := 0;
            lastButton1 := '0';
            syncOut1 <= '0';
            P1Button <= '0';
        elsif rising_edge(clock) then
        -- update buffer on sample interval
            if (sampleEn = ACTIVE) then
            -- shift previous inputs
                previous1(DEPTH - 2 downto 0) := previous1(DEPTH - 1 downto 1);
                -- add next synchronized input to buffer
                previous1(DEPTH - 1) := P1safeOutput;
            end if;
            -- count number of current value of signal
            count1 := 0;
            for i in previous1'range loop
                if (previous1(i) = previous1(0)) then
                    count1 := count1 + 1;
                end if;
            end loop;
        -- if majority of the samples match new value, update output
            if (count1 >= MIN_SAMPLES) then
                syncOut1 <= previous1(0);
            end if;
        -- default value 
            P1Button <= '0';
        -- waits until the player 1 has a new button press    
            if syncOut1 = '1' and lastButton1 = '0' then
                P1Button <= '1';
            end if;

        lastButton1 := syncOut1;
        end if;
    end process;
    -- sample raw signal to synchronize and further debounce
    -- in : (reset, clock) sampleEn, P2safeOutput, syncOut2
    -- out: P2Button
    DEBOUNCE_RIGHT: process (reset, clock) is
        variable previous2: std_logic_vector(DEPTH-1 downto 0);
        variable count2: integer range 0 to DEPTH;
        variable lastButton2: std_logic := '0';
    begin
        if (reset = ACTIVE) then
        -- clear to inactive on reset
            previous2 := (others => not ACTIVE);
            count2 := 0;
            lastButton2 := '0';
            syncOut2 <= '0';
            P2Button <= '0';
        elsif rising_edge(clock) then
        -- update buffer on sample interval
            if (sampleEn = ACTIVE) then
            -- shift previous inputs
                previous2(DEPTH - 2 downto 0) := previous2(DEPTH - 1 downto 1);
                -- add next synchronized input to buffer
                previous2(DEPTH - 1) := P2safeOutput;
            end if;
            -- count number of current value of signal
            count2 := 0;
            for i in previous2'range loop
                if (previous2(i) = previous2(0)) then
                    count2 := count2 + 1;
                end if;
            end loop;
        -- if majority of the samples match new value, update output
            
            if (count2 >= MIN_SAMPLES) then
                syncOut2 <= previous2(0);
            end if;
        -- default value
            P2Button <= '0';
        -- waits until player 2 has a new button press    
            if syncOut2 = '1' and lastButton2 = '0' then
                P2Button <= '1';
            end if;

        lastButton2 := syncOut2;
        end if;
     end process;
    
    -- debounced and synchronized signals 
    P1ONLY: P1Valid <= P1Button and not P2Button;
    P2ONLY: P2Valid <= P2Button and not P1Button;

    -- Increases speed whenever a point is scored
    -- in : (reset, clock) incSpeedEn
    -- out: currentSpeed           
    SPEED_SETTING: process(clock, reset) is
    variable start : boolean := true;
    begin
    if (reset = ACTIVE) then
        currentSpeed <= LED_SPEED;
        
    elsif rising_edge(clock) then
        -- initial speed of the LED on first round
        if (start = true) then  
            currentSpeed <= LED_SPEED;
            start := false;
        elsif (incSpeedEn = ACTIVE) then
            -- increases the enable signal rate
            if currentSpeed > 1000000 then
                currentSpeed <= currentSpeed - 1000000;
            end if;
        end if;
    end if;
    end process SPEED_SETTING;          
    -- sends a signal to move the LED 
    -- in : (reset, clock) currentSpeed
    -- out: moveEn
    SPEED: process(reset, clock) is
        variable count: integer range 0 to LED_SPEED;
    begin
    	--manage-count-value--------------------------------------------
        if (reset = ACTIVE) then
            count := 0;
        elsif (rising_edge(clock)) then
            moveEn <= not ACTIVE;
            if (count >= currentSpeed) then
                count := 0;
                moveEn <= ACTIVE;
            else
                count := count + 1;
          end if;
        end if;
       
    end process SPEED;

    -- controls the position of the LED
    -- in : (reset, clock) moveEn, holdMode, directionMode, serveContinue
    -- out: position
    BALL_POSITION: process(clock, reset) is
        variable count: integer := 15;

    begin
        if(reset = ACTIVE) then
            count := 15;
        elsif(rising_edge(clock)) then
            -- LED holds on the serving players end
            if(holdMode = ACTIVE) then
                if(directionMode = '1') then
                    count := 0;
                    -- increments count back down to start advancing LED
                    if (serveContinue = ACTIVE) then 
                        count := 15;
                    end if;
                elsif(directionMode = '0') then
                    count := 15;
                    if (serveContinue = ACTIVE) then 
                        count := 0;
                    end if;
                end if;
            elsif (moveEn = ACTIVE) then
                -- Controls count position
                if(directionMode = '1' and count > 0) then 
                    count := count - 1; 
                elsif(directionMode = '0' and count < 15) then 
                    count := count + 1;
                end if;
            end if;
       end if;
        position <= count;
    end process BALL_POSITION;
    
    
    -- bitmask the LEDS to the correct position
    -- in : (reset, clock) position
    -- out: LEDS
    LED_DRIVER: process(position) is 
    begin 
        LEDS <= (others => not ACTIVE);
        LEDS(position) <= ACTIVE;
    end process LED_DRIVER;

    -- Increments player 2's score
    -- in : (reset, clock) position
    -- out: LEDS
    P2_score: process(clock, reset)
    begin
        -- Manages score counting for player 2
        if (reset = ACTIVE) then
            P2Score <= 0;
        elsif rising_edge(clock) then
            if (P2ScoreEn = ACTIVE) then
                if (P2Score >= 0 and P2Score < 99) then 
                    P2Score <= P2Score + 1;
                else 
                    P2Score <= 99;
                end if;
            end if;
        end if;
    end process;

    P1_score: process(clock, reset)
    begin
        -- manages score counting for player 1
        if (reset = ACTIVE) then
            P1Score <= 0;
        elsif rising_edge(clock) then
            if (P1ScoreEn = ACTIVE) then
                if (P1Score >= 0 and P1Score < 99) then 
                    P1Score <= P1Score + 1;
                else 
                    P1Score <= 99;
                end if;
            end if;
        end if;
    end process;
    
    -- seperates the score into ones and tens
    P1_BCD_ONES: P1Ones <= std_logic_vector(to_unsigned((P1Score mod 10), 4));
    P1_BCD_TENS: P1Tens <= std_logic_vector(to_unsigned((P1Score / 10), 4));

    P2_BCD_ONES: P2Ones <= std_logic_vector(to_unsigned((P2Score mod 10), 4));
    P2_BCD_TENS: P2Tens <= std_logic_vector(to_unsigned((P2Score / 10), 4));
    
      
    -- Controls the winning score
    -- in : winCount
    -- out: winScore
    WIN_COUNT: process(winCount) is 
    begin 
         winScore <= 1; -- default value
         for i in 0 to 15 loop
            if (winCount(i) = '1') then 
                winScore <= i; -- sets win condition for score
            end if;
        end loop;
    end process WIN_COUNT;

    -- detects when player 1 or player 2 win
    P1WIN_DETECT: with P1winEn select
        P1win <= ACTIVE when ACTIVE,
                   not ACTIVE when others;
                   
    P2WIN_DETECT: with P2winEn select
        P2win <= ACTIVE when ACTIVE,
                   not ACTIVE when others;

    -- State machine for pong logic
    -- in : (reset, clock) currentState
    -- out: serveCount, currentState
    STATE_REG: process(clock, reset) is
    variable counter : integer range 1 to 197;
    begin
        if (reset = ACTIVE) then
            currentState <= P1_NEXT_SERVE;
            counter := 1;
        elsif (rising_edge(clock)) then
            currentState <= nextState;  
            if(currentState = SERVE_ALTERNATE) then
                counter := counter + 1;
            end if;   
        end if;
        serveCount <= counter;
    end process STATE_REG;

    -- Determines state transitions for pong logic
    -- in : (reset, clock), P1Valid, P2Valid, position, moveEn, P1Score, P2Score, serveCount, winScore, currentState
    -- out: directonMode, incSpeedEn, holdMode, P1ScoreEn, P2ScoreEn, P1Win, P2Win, serveContinue, nextState
    STATE_TRANS: process (all) is 
    begin
        directionMode <= '1';
        incSpeedEn <= not ACTIVE;
        holdMode <= not ACTIVE;
        P1ScoreEn <= not ACTIVE;
        P2ScoreEn <= not ACTIVE;
        P1win <= not ACTIVE;
        P2win <= not ACTIVE;
        serveContinue <= not ACTIVE;
        nextState <= currentState;
        
        

        case currentState is
            -- pong logic
            when P1_NEXT_SERVE =>
                holdMode <= ACTIVE;
                directionMode <= '1';
                
                if(P1Valid = ACTIVE) then
                    serveContinue <= ACTIVE;
                    nextState <= MOVE_RIGHT;
                end if;
            
            when P2_NEXT_SERVE => 
                holdMode <= ACTIVE;
                directionMode <= '0';
                
                if (P2Valid = ACTIVE) then 
                    serveContinue <= ACTIVE;
                    nextState <= MOVE_LEFT;
                end if;

            -- forces player 1 to press the button to serve
            when P1MOVE_BUFFER =>
                holdMode <= ACTIVE;
                directionMode <= '1';
                if (P1Valid = not ACTIVE) then 
                    nextState <= P1_NEXT_SERVE;
                else 
                    nextState <= P1MOVE_BUFFER;
                end if;

            -- forces player 2 to press the button to serve
            when P2MOVE_BUFFER => 
                holdMode <= ACTIVE;
                directionMode <= '0';
                if (P2Valid = not ACTIVE) then 
                    nextState <= P2_NEXT_SERVE;
                else
                    nextState <= P2MOVE_BUFFER;
                end if;
                
            when MOVE_RIGHT =>
                holdMode <= not ACTIVE;
                directionMode <= '1';
                if (P2Valid = ACTIVE) then
                    nextState <= P2_MISS;
                elsif (position = 0 and moveEn = not ACTIVE) then 
                    nextState <= P2_HIT_DETECTION;  
                end if;
                
            when MOVE_LEFT =>
                holdMode <= not ACTIVE;
                directionMode <= '0';
                if (P1Valid = ACTIVE) then
                    nextState <= P1_MISS;
                elsif (position = 15 and moveEn = not ACTIVE) then 
                    nextState <= P1_HIT_DETECTION;
                end if;
                
            when P1_HIT_DETECTION => 
                directionMode <= '0';
                if (P1Valid = not ACTIVE and moveEn = ACTIVE) then
                    nextState <= P1_MISS; 
                elsif (P1Valid = ACTIVE) then 
                    nextState <= MOVE_RIGHT;
                end if;
                
            when P2_HIT_DETECTION =>
                directionMode <= '1';
                if (P2Valid = not ACTIVE and moveEn = ACTIVE) then 
                    nextState <= P2_MISS;
                elsif (P2Valid = ACTIVE) then 
                    nextState <= MOVE_LEFT;
                end if;

            when P2_MISS => 
                P1ScoreEn <= ACTIVE;
                incSpeedEn <= ACTIVE;
                if (P1Score >= winScore and 
                ((P1Score + 1) - P2Score) >= 2) then
                    P1winEn <= ACTIVE;
                    nextState <= P_WIN;  
                else
                    nextState <= SERVE_ALTERNATE;         
                end if;         

            when P1_MISS => 
                P2ScoreEn <= ACTIVE;
                incSpeedEn <= ACTIVE;
                if(P2Score >= winScore and 
                ((P2Score + 1) - P1Score) >= 2) then
                    P2winEn <= ACTIVE;
                    nextState <= P_WIN; 
                else
                    nextState <= SERVE_ALTERNATE;
                end if;
                
            when P_WIN =>
                holdMode <= ACTIVE;
                if (P1Score > P2Score) then 
                    P1Win <= ACTIVE;
                elsif (P2Score > P1Score) then 
                    P2Win <= ACTIVE;
                end if;
                -- stays in P_WIN 
                nextState <= P_WIN;    
                
            when SERVE_ALTERNATE =>
                -- switches between P1 serve and P2 serves
                if (serveCount mod 2 = 0) then
                    nextState <= P1MOVE_BUFFER;
                    
                elsif (serveCount mod 2 = 1) then
                    nextState <= P2MOVE_BUFFER;
                end if;
                
            end case;
    end process STATE_TRANS;
    
end pong_ARCH;