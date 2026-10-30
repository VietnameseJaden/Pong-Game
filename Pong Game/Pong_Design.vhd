----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/27/2026 09:00:27 AM
-- Design Name: Lab4
-- Module Name: pong - Behavioral
-- Project Name: Ping Pong Game
-- Target Devices: 
-- Tool Versions: 
-- Description: Controls score mechanics and LED moving direction. 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity pong is
--  Port ( );
    port(
        clock: in std_logic;
        reset: in std_logic;
        
        
        LEDS: out std_logic_vector(15 downto 0);
        P1Ones: out std_logic_vector(3 downto 0);
        P2Ones: out std_logic_vector(3 downto 0));
end pong;

architecture pong_ARCH of pong is
    constant ACTIVE: std_logic:= '1';
    constant COUNT_10KHZ: integer:= 10000;
    signal moveEn: std_logic;
    signal holdMode: std_logic;
    signal directionMode: std_logic;
    signal position: integer;
    signal P1miss: std_logic;
    signal P2miss: std_Logic;
    signal P2En: std_logic;
    signal P1En: std_logic;
    signal P2ScoreEn: std_logic;
    signal P2Score: integer;
    signal P1ScoreEn: std_logic;
    signal P1Score: integer;
    type States_t is (P1_NEXT_SERVE, P2_NEXT_SERVE, MOVE_RIGHT, MOVE_LEFT, 
                    P1_HIT_DETECTION, P2_HIT_DETECTION, P1_MISS, P2_MISS,
                    P1_SCOREIN, P2_SCOREIN, P_WIN);
    signal currentState: States_t; 
    signal nextState: States_t;
begin

    SPEED: process(reset, clock) is
        variable count: integer range 0 to COUNT_10KHZ;
    begin
    	--manage-count-value--------------------------------------------
        if (reset = ACTIVE) then
            count := 0;
        elsif (rising_edge(clock)) then
            if (count = COUNT_10KHZ) then
                count := 0;
            else
                count := count + 1;
            end if;
        end if;
        
        --update-enable-signal-------------------------------------------
        moveEn <= not ACTIVE;  --default value unless count reaches terminal
        if (count=COUNT_10KHZ) then
        	moveEn <= ACTIVE;
        end if;
    end process SPEED;
    
    BALL_POSITION: process(clock, reset) is
        variable count: integer := 16;
    begin
        if(reset = ACTIVE) then
            count := 15;
        elsif(rising_edge(clock)) then
            if(moveEn = ACTIVE) then
                if(holdMode = '1') then
                    if(directionMode = '1') then
                        count := 15;
                    end if;
                    if(directionMode = '0') then
                        count := 0;
                    end if;
                elsif(directionMode = '1' and position > 0) then 
                    count := count - 1; 
                elsif(directionMode = '0' and position < 15) then 
                    count := count + 1;
            end if;
       end if;
     end if;
        position <= count;
    end process BALL_POSITION;
    
    LED_DRIVER: process(position) is 
    begin 
        LEDS <= (others => not ACTIVE);
        LEDS(position) <= ACTIVE;
    end process LED_DRIVER;
    
    P2_score: process(clock, reset) is 
    begin
        if (reset = ACTIVE) then
            P2Score <= 0;
        elsif (clock = ACTIVE) then
            if (position = 0 and P2ScoreEn = ACTIVE) then
                P2Score <= P2Score + 1;
            elsif (position = 0 and P2ScoreEn = not ACTIVE) then 
                P1Score <= P1Score + 1;
            end if;
        end if;
    end process P2_score;
    
    P1_score: process(clock, reset) is
    begin 
        if (reset = ACTIVE) then
            P1Score <= 0;
        elsif (clock = ACTIVE) then
            if (position = 0 and P2ScoreEn = ACTIVE) then
                P1Score <= P1Score + 1;
            elsif (position = 0 and P2ScoreEn = not ACTIVE) then
                P2Score <= P2Score + 1;
            end if;
        end if;
    end process P1_score;
    
    P2CALC_ONES: P2Ones <= std_logic_vector(to_unsigned(P2Score, 4));
    P1CALC_ONES: P1Ones <= std_logic_vector(to_unsigned(P2Score, 4));
    
    STATE_REG: process(clock, reset) is
    begin
        if (reset) then
            currentState <= P1_NEXT_SERVE;
        elsif (clock) then
            currentState <= nextState;
        end if;
    end process STATE_REG;
    
    STATE_TRANS: process (all) is 
    begin
        holdMode <= not ACTIVE;
        directionMode <= '1';
        P1ScoreEn <= not ACTIVE;
        P2ScoreEn <= not ACTIVE;
        nextState <= currentState;

        if (nextState = P1_NEXT_SERVE) then
            holdMode <= ACTIVE;
            directionMode <= '1';
            nextState <= MOVE_RIGHT;

        elsif (nextState = MOVE_RIGHT) then 
            holdMode <= not ACTIVE;
            directionMode <= '1';
            if (P2En = '1') then
                nextState <= P2_MISS;
            end if;
            if (position = 0) then 
                nextState <= P2_HIT_DETECTION;     
            end if;
        elsif (nextState = P2_MISS) then 
                P1ScoreEn <= ACTIVE;
        elsif (nextState = P2_HIT_DETECTION) then
                if (P2En = not ACTIVE and moveEn = ACTIVE) then 
                    nextState <= P2_MISS;
                end if;
                if (P2En = ACTIVE) then 
                    nextState <= MOVE_LEFT;
                end if;
        end if;
    end process STATE_TRANS;
    
end pong_ARCH;
