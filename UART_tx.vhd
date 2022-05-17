
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



entity UART_tx is

    generic(
        BAUD_CLK_TICKS: integer := 10); -- BAUD_CLK_TICKS = Horloge / Debit Baud (Dans ce cas 10 Front montant)

    port(
        clk            : in  std_logic; -- Horloge Principal
        reset          : in  std_logic;
        tx_start       : in  std_logic;
        tx_data_in     : in  std_logic_vector (7 downto 0); -- Donnée d'entré parallèle
        tx_data_out    : out std_logic -- Donnée sortie en parallèle
        );
end UART_tx;


architecture Behavioral of UART_tx is

    type tx_states_t is (IDLE, START, DATA, STOP); -- Idle stat, Start bit, Stop Bit and data
    signal tx_state  : tx_states_t := IDLE; -- état initial IDLE


    signal horloge_baud_rate     : std_logic:= '0'; -- Horloge qui definit le rythme de compteur

    signal data_index        : integer range 0 to 7 := 0; -- Indice commence par 0
    signal data_index_reset  : std_logic := '1'; -- réinitialisation de compteur d'indice
    signal stored_data       : std_logic_vector(7 downto 0) := (others=>'0'); -- enregistre la donné

    signal start_detected    : std_logic := '0'; -- Detection de demarrage
    signal start_reset       : std_logic := '0'; -- réinitialisation

begin




-- Ce generateur génere une horloge de UART a chaque fin de compteur des cycle
-- BAUD_CLK_TICKS = Horloge / Debit Baud
    horloge_baud_rate_generator: process(clk)
    variable compteur_baud: integer range 0 to (BAUD_CLK_TICKS - 1) := (BAUD_CLK_TICKS - 1);
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                horloge_baud_rate <= '0';
                compteur_baud := (BAUD_CLK_TICKS - 1);
            else
                if (compteur_baud = 0) then -- Compteur termine 
                    horloge_baud_rate <= '1'; -- Envoit un signal
                    compteur_baud := (BAUD_CLK_TICKS - 1); -- réinitialisation du compteur à l'état initial
                else
                    horloge_baud_rate <= '0'; -- Fonctionnement normal du compteur
                    compteur_baud := compteur_baud - 1;  
                end if;
            end if;
        end if;
    end process horloge_baud_rate_generator;


-- Block responsable de la detection de l'entrée
    tx_start_detector: process(clk)
    begin
        if rising_edge(clk) then
            if (reset ='1') or (start_reset = '1') then
                start_detected <= '0';
            else
                if (tx_start = '1') and (start_detected = '0') then -- ligne libre et tx_start = '1'
                    start_detected <= '1';
                    stored_data <= tx_data_in; -- on enregistre la donnée
                end if;
            end if;
        end if;
    end process tx_start_detector;



-- Compteur de 0 jusqu'à 7 (selon le nombre de bit de la donné) synchronisé avec la nouvelle horloge de baud,
-- Utiliser pour faire la transformation Parallel (stored_data) serie (tx_data_out)
-- Utilisé dans le UART_tx_etat pour traverser la donnée stored_data et l'envoyer bit par bit
    data_index_counter: process(clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') or (data_index_reset = '1') then
                data_index <= 0;
            elsif (horloge_baud_rate = '1') then -- Fin de compteur generateur de baud 
                data_index <= data_index + 1;
            end if;
        end if;
    end process data_index_counter;


--  UART_tx_etat represente l'état de bit

    UART_tx_etat: process(clk)
    begin
        if rising_edge(clk) then
            if (reset = '1') then
                tx_state <= IDLE;
                data_index_reset <= '1';   -- compteur des indice en attente
                start_reset <= '1';        -- detecteur de start en attente
                tx_data_out <= '1';        -- Ligne dans est de '1' pour l'état IDLE
            else
                if (horloge_baud_rate = '1') then   -- Le block s'active lors d'une transition de la nouvelle horloge (horloge_baud_rate)
                    case tx_state is

                        when IDLE =>

                            data_index_reset <= '1';    -- compteur des indice en attente
                            start_reset <= '0';         -- le detecteur de start attend des impulsions
                            tx_data_out <= '1';         -- etat IDLE : tx_data_out = '1'

                            if (start_detected = '1') then -- Detection du start
                                tx_state <= START; -- Transition à l'état START
                            end if;

                        when START =>

                            data_index_reset <= '0';   -- commencer le compteur des indice
                            tx_data_out <= '0';        -- Envoit du start bit '0'

                            tx_state <= DATA; -- Transition de l'etat

                        when DATA =>

                            tx_data_out <= stored_data(data_index);   -- Envoit 1 bit par cycle 8 fois

                            if (data_index = 7) then
                                data_index_reset <= '1';              -- Arrét du compteur des indeices quand il atteint 8 
                                tx_state <= STOP; -- Transition au dernier etat
                            end if;

                        when STOP =>

                            tx_data_out <= '1';     -- Envoit du stop bit '1'
                            start_reset <= '1';     -- prépare le detecteur pour la prochaine detection

                            tx_state <= IDLE; --Transition etat IDLE

                        when others =>
                            tx_state <= IDLE;
                    end case;
                end if;
            end if;
        end if;
    end process UART_tx_etat;


end Behavioral;
