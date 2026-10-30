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
        
        holdMode: in std_logic; 
        directionMode: in std_logic;
        
        LEDS: out std_logic_vector(15 downto 0));
end pong;

architecture pong_ARCH of pong is
    constant ACTIVE: std_logic:= '1';
    constant COUNT_10KHZ: integer:= 10000;
    signal moveEn: std_logic;
    signal position: integer;
    signal P1miss: std_logic;
    signal P2En: std_logic;
    signal P1En: std_logic;
    signal P2Score: integer;
    signal P1Score: integer;
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
    
    P2_SCORE: process (clock, reset) is
    begin
        if(position = 0 and P2En = '1') then
            P2Score <= P2Score + 1;
        end if;
    end process P2_SCORE;

    P1_SCORE: process(clock, reset) is 
    begin 
        if(position = 15 and P1En = '1') then
            P1Score <= P1Score + 1;
        end if;
    end process P1_SCORE;
    
    
end pong_ARCH;
