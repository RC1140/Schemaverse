-- Schemaverse 
-- Created by Josh McDougall
-- v0.14.2 - Now I remember where I put that ship

create language 'plpgsql';

CREATE SEQUENCE round_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;

CREATE SEQUENCE tic_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
  
CREATE OR REPLACE FUNCTION GET_PLAYER_ID(check_username name) RETURNS integer AS $get_player_id$
DECLARE 
	found_player_id integer;
BEGIN
	SELECT id INTO found_player_id FROM player WHERE username=check_username;
	RETURN found_player_id;
END
$get_player_id$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION GET_PLAYER_USERNAME(check_player_id integer) RETURNS character varying AS $get_player_username$
DECLARE 
	found_username character varying;
BEGIN
	SELECT username INTO found_username FROM player WHERE id=check_player_id;
	RETURN found_username;
END
$get_player_username$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION GET_PLAYER_ERROR_CHANNEL(player_name character varying default SESSION_USER) RETURNS character varying AS 
$get_player_error_channel$
DECLARE 
	found_error_channel character varying;
BEGIN
	IF CURRENT_USER = 'schemaverse' THEN
		SELECT error_channel INTO found_error_channel FROM player WHERE username=player_name;
        ELSE
		SELECT error_channel INTO found_error_channel FROM my_player LIMIT 1;
	END IF;
	RETURN found_error_channel;
END
$get_player_error_channel$ LANGUAGE plpgsql;

CREATE TABLE variable
(
	name character varying NOT NULL,
	private boolean,
	numeric_value integer,
	char_value character varying,
	description TEXT,
	player_id integer NOT NULL DEFAULT 0, 
  	CONSTRAINT pk_variable PRIMARY KEY (name, player_id)
);

CREATE VIEW public_variable AS SELECT * FROM variable WHERE (private='f' AND player_id=0) OR player_id=GET_PLAYER_ID(SESSION_USER);

INSERT INTO variable VALUES 
	('MINE_BASE_FUEL','f',1,'','This value is used as a multiplier for fuel discovered from all planets'::TEXT,0),
	('UNIVERSE_CREATOR','t',9702000,'','The answer which creates the universe'::TEXT,0), 
	('EXPLODED','f',60,'','After this many tics, a ship will explode. Cost of a base ship will be returned to the player'::TEXT,0),
	('MAX_SHIP_SKILL','f',500,'','This is the total amount of skill a ship can have (attack + defense + engineering + prospecting)'::TEXT,0),
	('MAX_SHIP_RANGE','f',2000,'','This is the maximum range a ship can have'::TEXT,0),
	('MAX_SHIP_FUEL','f',16000,'','This is the maximum fuel a ship can have'::TEXT,0),
	('MAX_SHIP_SPEED','f',5000,'','This is the maximum speed a ship can travel'::TEXT,0),
	('MAX_SHIP_HEALTH','f',1000,'','This is the maximum health a ship can have'::TEXT,0),
	('ROUND_START_DATE','f',0,'2011-04-17','The day the round started.'::TEXT,0),
	('ROUND_LENGTH','f',0,'7 days','The length of time a round takes to complete'::TEXT,0),
	('DEFENSE_EFFICIENCY', 'f', 50, '', 'Used to calculate attack with defense'::TEXT,0);

	
CREATE OR REPLACE FUNCTION GET_NUMERIC_VARIABLE(variable_name character varying) RETURNS integer AS $get_numeric_variable$
DECLARE
	value integer;
BEGIN
	IF CURRENT_USER = 'schemaverse' THEN
		SELECT numeric_value INTO value FROM variable WHERE name = variable_name and player_id=0;
	ELSE 
		SELECT numeric_value INTO value FROM public_variable WHERE name = variable_name;
	END IF;
	RETURN value; 
END $get_numeric_variable$  LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION GET_CHAR_VARIABLE(variable_name character varying) RETURNS character varying AS $get_char_variable$
DECLARE
	value character varying;
BEGIN
	IF CURRENT_USER = 'schemaverse' THEN
		SELECT char_value INTO value FROM variable WHERE name = variable_name and player_id=0;
	ELSE
		SELECT char_value INTO value FROM public_variable WHERE name = variable_name;
	END IF;
	RETURN value; 
END $get_char_variable$  LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION SET_NUMERIC_VARIABLE(variable_name character varying, new_value integer) RETURNS integer AS $set_numeric_variable$
BEGIN
	IF (SELECT count(*) FROM variable WHERE name=variable_name AND player_id=GET_PLAYER_ID(SESSION_USER)) = 1 THEN
		UPDATE variable SET numeric_value=new_value WHERE  name=variable_name AND player_id=GET_PLAYER_ID(SESSION_USER);
	ELSEIF (SELECT count(*) FROM variable WHERE name=variable_name AND player_id=0) = 1 THEN
		EXECUTE 'NOTIFY ' || get_player_error_channel() ||', ''Cannot update a system variable'';';
	ELSE 
		INSERT INTO variable VALUES(variable_name,'f',new_value,'','',GET_PLAYER_ID(SESSION_USER));
	END IF;
	RETURN new_value; 
END $set_numeric_variable$ SECURITY definer LANGUAGE plpgsql ;

CREATE OR REPLACE FUNCTION SET_CHAR_VARIABLE(variable_name character varying, new_value character varying) RETURNS character varying AS 
$set_char_variable$
BEGIN
	IF (SELECT count(*) FROM variable WHERE name=variable_name AND player_id=GET_PLAYER_ID(SESSION_USER)) = 1 THEN
		UPDATE variable SET char_value=new_value WHERE  name=variable_name AND player_id=GET_PLAYER_ID(SESSION_USER);
	ELSEIF (SELECT count(*) FROM variable WHERE name=variable_name AND player_id=0) = 1 THEN
		EXECUTE 'NOTIFY ' || get_player_error_channel() ||', ''Cannot update a system variable'';';
	ELSE 
		INSERT INTO variable VALUES(variable_name,'f',0,new_value,'',GET_PLAYER_ID(SESSION_USER));
	END IF;
	RETURN new_value; 
END $set_char_variable$ SECURITY definer LANGUAGE plpgsql;


CREATE TABLE price_list
(
	code character varying NOT NULL PRIMARY KEY,
	cost integer NOT NULL,
	description TEXT
);


INSERT INTO price_list VALUES
	('SHIP', 100000, 'HOLY CRAP. A NEW SHIP!'),
	('FLEET_RUNTIME', 10000000, 'Add one minute of runtime to a fleet script'),
	('MAX_HEALTH', 25, 'Increases a ships MAX_HEALTH by one'),
	('MAX_FUEL', 1, 'Increases a ships MAX_FUEL by one'),
	('MAX_SPEED', 1, 'Increases a ships MAX_SPEED by one'),
	('RANGE', 25, 'Increases a ships RANGE by one'),
	('ATTACK', 25,'Increases a ships ATTACK by one'),
	('DEFENSE', 25, 'Increases a ships DEFENSE by one'),
	('ENGINEERING', 25, 'Increases a ships ENGINEERING by one'),
	('PROSPECTING', 25, 'Increases a ships PROSPECTING by one');
	
	CREATE OR REPLACE FUNCTION GENERATE_STRING(len integer) RETURNS CHARACTER VARYING AS $generate_string$
BEGIN
	RETURN array_to_string(ARRAY(SELECT chr((65 + round(random() * 25)) :: integer) FROM generate_series(1,len)), '');
END
$generate_string$ LANGUAGE plpgsql;

CREATE TABLE player
(
	id integer NOT NULL PRIMARY KEY,
	username character varying NOT NULL UNIQUE,
	password character(40) NOT NULL,			-- 'md5' + MD5(password+username) 
	created timestamp NOT NULL DEFAULT NOW(),
	balance numeric NOT NULL DEFAULT '10010000',
	fuel_reserve integer NOT NULL DEFAULT '1000',
	error_channel CHARACTER(10) NOT NULL DEFAULT lower(generate_string(10)),
	starting_fleet integer,
	CONSTRAINT ck_balance CHECK (balance >= 0::numeric),
  	CONSTRAINT ck_fuel_reserve CHECK (fuel_reserve >= 0)
);


CREATE SEQUENCE player_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;

INSERT INTO player(id, username, password, fuel_reserve, balance) VALUES(0,'schemaverse','nopass',100000,100000); 

CREATE VIEW my_player AS 
	SELECT id, username, created, balance, fuel_reserve, password, error_channel, starting_fleet
	 FROM player WHERE username=SESSION_USER;

ALTER TABLE variable ADD CONSTRAINT fk_variable_player_id FOREIGN KEY (player_id)
      REFERENCES player (id) MATCH SIMPLE; 

CREATE RULE public_variable_update AS ON UPDATE to public_variable
	DO INSTEAD UPDATE variable 
		SET 
			numeric_value=NEW.numeric_value,
			description=NEW.description 
		WHERE 
			name=NEW.name AND player_id=GET_PLAYER_ID(SESSION_USER);

CREATE RULE public_variable_insert AS ON INSERT to public_variable
	DO INSTEAD INSERT INTO variable(name, char_value, numeric_value, description, player_id) VALUES(
			NEW.name,
			NEW.char_value, 
			NEW.numeric_value,
			NEW.description,
			GET_PLAYER_ID(SESSION_USER));

CREATE RULE public_variable_delete AS ON DELETE to public_variable
	DO INSTEAD DELETE FROM variable 
		WHERE 
			name=OLD.name AND player_id=GET_PLAYER_ID(SESSION_USER);


CREATE OR REPLACE FUNCTION VARIABLE_INSERT() RETURNS trigger AS $variable_insert$
	BEGIN
	IF (SELECT count(*) FROM variable WHERE player_id=0 and name=NEW.name) = 1 THEN
		RETURN OLD;
	ELSE
	       RETURN NEW;
	END IF;
END $variable_insert$ LANGUAGE plpgsql;

CREATE TRIGGER VARIABLE_INSERT BEFORE INSERT ON variable
  FOR EACH ROW EXECUTE PROCEDURE VARIABLE_INSERT();



	--Needs a trigger to alter the user account. Don't feel like actually writing this right now. 
	--A bit worried it is a security risk unless the new password is checked thoroughly. Otherwise they could inject into the alter user statement 
	--CREATE RULE my_player AS ON UPDATE TO player 
	-- DO INSTEAD UPDATE player SET password=NEW.password WHERE username=SESSION_USER; ON UPDATE CASCADE ON DELETE CASCADE
	
CREATE RULE my_player_starting_fleet AS ON UPDATE to my_player
	DO INSTEAD UPDATE player SET starting_fleet=NEW.starting_fleet WHERE id=NEW.id;

CREATE VIEW online_players AS
	SELECT id, username FROM player
		WHERE username in (SELECT DISTINCT usename FROM pg_stat_activity);

CREATE OR REPLACE FUNCTION PLAYER_CREATION() RETURNS trigger AS $player_creation$
BEGIN
	execute 'CREATE ROLE ' || NEW.username || ' WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE ENCRYPTED PASSWORD '''|| NEW.password ||'''  IN GROUP players'; 

	UPDATE planet SET conqueror_id=NEW.id, mine_limit=50, fuel=3000000, difficulty=10 
			WHERE planet.id = 
				(SELECT id FROM planet 
					WHERE (planet.location_x > 50000 OR planet.location_x < -50000) 
						AND (planet.location_y > 50000 OR planet.location_y < -50000) 
						AND conqueror_id is null ORDER BY RANDOM() LIMIT 1);
	RETURN NEW;
END
$player_creation$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER PLAYER_CREATION AFTER INSERT ON player
  FOR EACH ROW EXECUTE PROCEDURE PLAYER_CREATION(); 


CREATE OR REPLACE FUNCTION GET_PLAYER_ID(check_username name) RETURNS integer AS $get_player_id$
DECLARE 
	found_player_id integer;
BEGIN
	SELECT id INTO found_player_id FROM player WHERE username=check_username;
	RETURN found_player_id;
END
$get_player_id$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION GET_PLAYER_USERNAME(check_player_id integer) RETURNS character varying AS $get_player_username$
DECLARE 
	found_username character varying;
BEGIN
	SELECT username INTO found_username FROM player WHERE id=check_player_id;
	RETURN found_username;
END
$get_player_username$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION GET_PLAYER_ERROR_CHANNEL(player_name character varying default SESSION_USER) RETURNS character varying AS 
$get_player_error_channel$
DECLARE 
	found_error_channel character varying;
BEGIN
	IF CURRENT_USER = 'schemaverse' THEN
		SELECT error_channel INTO found_error_channel FROM player WHERE username=player_name;
        ELSE
		SELECT error_channel INTO found_error_channel FROM my_player LIMIT 1;
	END IF;
	RETURN found_error_channel;
END
$get_player_error_channel$ LANGUAGE plpgsql;

CREATE TABLE item
(
	system_name character varying NOT NULL PRIMARY KEY,
	name character varying NOT NULL,
	description TEXT,
	howto TEXT,
	persistent boolean NOT NULL DEFAULT 'f',
	script text,
	creator integer NOT NULL REFERENCES player(id),
        approved boolean default 'f',
        round_started integer
);

CREATE TABLE item_location
(
	system_name character varying NOT NULL REFERENCES item(system_name),
	location_x integer NOT NULL default RANDOM(),
	location_y integer NOT NULL default RANDOM()
);


CREATE OR REPLACE FUNCTION CREATE_ITEM() RETURNS trigger AS $create_item$
BEGIN

        NEW.approved    := 'f';
        NEW.creator     := GET_PLAYER_ID(SESSION_USER);
        NEW.round_started := 0;

       RETURN NEW;
END
$create_item$ LANGUAGE plpgsql;


CREATE TRIGGER CREATE_ITEM BEFORE INSERT ON item
  FOR EACH ROW EXECUTE PROCEDURE CREATE_ITEM();


CREATE OR REPLACE FUNCTION ITEM_SCRIPT_UPDATE() RETURNS trigger AS $item_script_update$
DECLARE
       current_round integer;
       player_id integer;
BEGIN

        player_id := GET_PLAYER_ID(SESSION_USER);

        IF  SESSION_USER = 'schemaverse' THEN
               IF NEW.approved='t' AND OLD.approved='f' THEN
                        IF NEW.round_started=0 THEN
                                SELECT last_value INTO NEW.round_started FROM round_seq;
                        END IF;
                      
                 EXECUTE NEW.script::TEXT;

                END IF;
        ELSEIF NOT player_id = OLD.creator THEN
                RETURN OLD;
        ELSE
                IF NOT OLD.approved = NEW.approved THEN
                        NEW.approved='f';
                END IF;

                IF NOT (NEW.script = OLD.script) THEN
                        NEW.approved='f';
               END IF;
        END IF;

       RETURN NEW;
END $item_script_update$ LANGUAGE plpgsql;

CREATE TRIGGER ITEM_SCRIPT_UPDATE BEFORE UPDATE ON item
  FOR EACH ROW EXECUTE PROCEDURE ITEM_SCRIPT_UPDATE();



	CREATE OR REPLACE FUNCTION CONVERT_RESOURCE(current_resource_type character varying, amount integer) RETURNS integer as $convert_resource$
DECLARE
	amount_of_new_resource integer;
	fuel_check integer;
	money_check integer;
BEGIN
	SELECT INTO fuel_check, money_check fuel_reserve, balance FROM player WHERE id=GET_PLAYER_ID(SESSION_USER);
	IF current_resource_type = 'FUEL' THEN
		IF amount >= 0 AND  amount <= fuel_check THEN
			SELECT INTO amount_of_new_resource (fuel_reserve/balance*amount)::integer FROM player WHERE id=0;
			UPDATE player SET fuel_reserve=fuel_reserve-amount, balance=balance+amount_of_new_resource WHERE id=GET_PLAYER_ID(SESSION_USER);
			--UPDATE player SET balance=balance-amount, fuel_reserve=fuel_reserve+amount_of_new_resource WHERE id=0;
		ELSE
  			EXECUTE 'NOTIFY ' || get_player_error_channel() ||', ''You do not have that much fuel to convert'';';
		END IF;
	ELSEIF current_resource_type = 'MONEY' THEN
		IF  amount >= 0 AND amount <= money_check THEN
			SELECT INTO amount_of_new_resource (balance/fuel_reserve*amount)::integer FROM player WHERE id=0;
			UPDATE player SET balance=balance-amount, fuel_reserve=fuel_reserve+amount_of_new_resource WHERE id=GET_PLAYER_ID(SESSION_USER);
			--UPDATE player SET fuel_reserve=fuel_reserve-amount, balance=balance+amount_of_new_resource WHERE id=0;

		ELSE
  			EXECUTE 'NOTIFY ' || get_player_error_channel() ||', ''You do not have that much money to convert'';';
		END IF;
	END IF;

	RETURN amount_of_new_resource;
END
$convert_resource$ LANGUAGE plpgsql SECURITY DEFINER;



CREATE OR REPLACE FUNCTION DISCOVER_ITEM() RETURNS trigger as $discover_item$
DECLARE
	found_item RECORD;

BEGIN
	FOR found_item IN SELECT * FROM item_location WHERE location_x=NEW.location_x AND location_y=NEW.location_y LOOP
		DELETE FROM item_location WHERE location_x=found_item.location_x AND location_y=found_item.location_y AND system_name=found_item.system_name;
		INSERT INTO player_inventory(player_id, item) VALUES(NEW.player_id, found_item.system_name);

		INSERT INTO event(action, player_id_1, ship_id_1, location_x, location_y, descriptor_string, public, tic)
			VALUES('FIND_ITEM',NEW.player_id, NEW.id , NEW.location_x, NEW.location_y, found_item.system_name, 'f',(SELECT last_value FROM tic_seq));

	END LOOP;
	RETURN NEW;	
END
$discover_item$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER DISCOVER_ITEM AFTER UPDATE ON ship
  FOR EACH ROW EXECUTE PROCEDURE DISCOVER_ITEM();


CREATE TABLE action 
(
	name character(30) NOT NULL PRIMARY KEY,
	string TEXT NOT NULL
);
			
INSERT INTO action VALUES 
	('BUY_SHIP','(#%player_id_1%)%player_name_1% has purchased a new ship (#%ship_id_1%)%ship_name_1% and sent it to location %location_x%,%location_y%'::TEXT),
	('UPGRADE_FLEET','(#%player_id_1%)%player_name_1%''s new fleet (#%referencing_id%)%descriptor_string% has been upgraded'::TEXT),
	('UPGRADE_SHIP','(#%player_id_1%)%player_name_1% has upgraded the %descriptor_string% on ship (#%ship_id_1%)%ship_name_1% +%descriptor_numeric%'::TEXT),
	('REFUEL_SHIP','(#%player_id_1%)%player_name_1% has refueled the ship (#%ship_id_1%)%ship_name_1% +%descriptor_numeric%'::TEXT),
	('ATTACK','(#%player_id_1%)%player_name_1%''s ship (#%ship_id_1%)%ship_name_1% has attacked (#%player_id_2%)%player_name_2%''s ship (#%ship_id_2%)%ship_name_2% causing %descriptor_numeric% of damage'::TEXT),
	('EXPLODE','(#%player_id_1%)%player_name_1%''s ship (#%ship_id_1%)%ship_name_1% has been destroyed'::TEXT),
	('MINE_SUCCESS','(#%player_id_1%)%player_name_1%''s ship (#%ship_id_1%)%ship_name_1% has successfully mined %descriptor_numeric% fuel from the planet (#%referencing_id%)%planet_name%'::TEXT),
	('MINE_FAIL','(#%player_id_1%)%player_name_1%''s ship (#%ship_id_1%)%ship_name_1% has failed to mine the planet (#%referencing_id%)%planet_name%'::TEXT),
	('REPAIR','(#%player_id_1%)%player_name_1%''s ship (#%ship_id_1%)%ship_name_1% has repaired (#%ship_id_2%)%ship_name_2% by %descriptor_numeric%'::TEXT),
	('TRADE_START','(#%player_id_1%)%player_name_1% has started a trade (#%referencing_id%) with (#%player_id_2%)%player_name_2%'::TEXT),
	('TRADE_ADD_ITEM','(#%player_id_1%)%player_name_1% has added %descriptor_numeric% of %descriptor_string% to the trade (#%referencing_id%)'::TEXT),
	('TRADE_ADD_SHIP','(#%player_id_1%)%player_name_1% has added the ship (#%ship_id_1%)%ship_name_1% to the trade (#%referencing_id%)'::TEXT),
	('TRADE_DELETE_ITEM','(#%player_id_1%)%player_name_1% has removed %descriptor_numeric% of %descriptor_string% from the trade (#%referencing_id%)'::TEXT),
	('TRADE_DELETE_SHIP','(#%player_id_1%)%player_name_1% has deleted the ship (#%ship_id_1%)%ship_name_1% from the trade (#%referencing_id%)'::TEXT),
	('TRADE_CANCEL','(#%player_id_1%)%player_name_1% has canceled the trade (#%referencing_id%) with (#%player_id_2%)%player_name_2%'::TEXT),
	('TRADE_CONFIRM','(#%player_id_1%)%player_name_1% has confirmed their portion of trade (#%referencing_id%)'::TEXT),
	('TRADE_COMPLETE','Trade (#%referencing_id) between (#%player_id_1%)%player_name_1% and (#%player_id_2%)%player_name_2% is complete'::TEXT),
	('CONQUER','(#%player_id_1%)%player_name_1% has conquered (#%referencing_id%)%planet_name% from (#%player_id_2%)%player_name_2%' ::TEXT),
	('FIND_ITEM','(#%player_id_1%)%player_name_1% has found a %descriptor_string% floating out in space'::TEXT);


-- Allows players to add actions for items they create
CREATE OR REPLACE FUNCTION EDIT_ACTION() RETURNS trigger as $edit_action$
DECLARE
	check_creator integer;
BEGIN
	IF SESSION_USER = 'schemaverse' THEN
		RETURN NEW;
	ELSE 
		SELECT count(*) INTO check_creator FROM item WHERE creator=GET_PLAYER_ID(SESSION_USER) AND system_name=NEW.name;
		IF check_creator > 0 THEN
			RETURN NEW;
		END IF;
	END IF;
        RETURN NULL;
END
$edit_action$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER EDIT_ACTION BEFORE INSERT OR UPDATE ON action
  FOR EACH ROW EXECUTE PROCEDURE EDIT_ACTION();




CREATE TABLE event
(
	id integer NOT NULL PRIMARY KEY,
	action character(30) NOT NULL REFERENCES action(name),
	player_id_1 integer REFERENCES player(id),
	ship_id_1 integer REFERENCES ship(id), 
	player_id_2 integer REFERENCES player(id), 
	ship_id_2 integer REFERENCES ship(id),
	referencing_id integer,  
	descriptor_numeric numeric, 
	descriptor_string CHARACTER VARYING, 
	location_x integer, 
	location_y integer, 
	public boolean, 
	tic integer NOT NULL,
	toc timestamp NOT NULL DEFAULT NOW()
);

CREATE TABLE event_archive
(	
	round integer NOT NULL,
	event_id integer NOT NULL,
	action character(30) NOT NULL REFERENCES action(name),
	player_id_1 integer REFERENCES player(id),
	ship_id_1 integer REFERENCES ship(id), 
	player_id_2 integer REFERENCES player(id), 
	ship_id_2 integer REFERENCES ship(id),
	referencing_id integer,  
	descriptor_numeric numeric, 
	descriptor_string CHARACTER VARYING, 
	location_x integer, 
	location_y integer, 
	public boolean, 
	tic integer NOT NULL,
	toc timestamp NOT NULL DEFAULT NOW(),
 	CONSTRAINT event_archive_pkey PRIMARY KEY (round, event_id)
);

CREATE SEQUENCE event_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;


CREATE VIEW my_events AS
SELECT
	event.id as id,
	event.action as action,
	event.player_id_1 as player_id_1,
	event.ship_id_1 as ship_id_1, 
	event.player_id_2 as player_id_2, 
	event.ship_id_2 as ship_id_2,  
	event.referencing_id as referencing_id,
	event.descriptor_numeric as descriptor_numeric, 
	event.descriptor_string as descriptor_string, 
	event.location_x as location_x, 
	event.location_y as location_y, 
	event.public as public, 
	event.tic as tic, 
	event.toc as toc
FROM event
WHERE 
	( 
		GET_PLAYER_ID(SESSION_USER) IN (event.player_id_1, event.player_id_2)
		OR event.public='t' 
	)
AND event.tic < (SELECT last_value FROM tic_seq);


CREATE OR REPLACE FUNCTION READ_EVENT(read_event_id integer) RETURNS 
TEXT AS $read_event$
DECLARE
	full_text TEXT;
BEGIN
	-- Sometimes you just write some dirty code... 
	SELECT  
	replace(
	 replace(
	  replace(
	   replace(
	    replace(
	     replace(
	      replace(
	       replace(
	        replace(
	         replace(
	          replace(
	           replace(
	            replace(
	             replace(action.string,
	              '%player_id_1%', 	player_id_1::TEXT),
	             '%player_name_1%', GET_PLAYER_USERNAME(player_id_1)),
	            '%player_id_2%', 	COALESCE(player_id_2::TEXT,'Unknown')),
	           '%player_name_2%', 	COALESCE(GET_PLAYER_USERNAME(player_id_2),'Unknown')),
	          '%ship_id_1%', 	COALESCE(ship_id_1::TEXT,'Unknown')),
	         '%ship_id_2%', 	COALESCE(ship_id_2::TEXT,'Unknown')),
	        '%ship_name_1%', 	COALESCE(GET_SHIP_NAME(ship_id_1),'Unknown')),
	       '%ship_name_2%', 	COALESCE(GET_SHIP_NAME(ship_id_2),'Unknown')),
	      '%location_x%', 		COALESCE(location_x::TEXT,'Unknown')),
	     '%location_y%', 		COALESCE(location_y::TEXT,'Unknown')),
	    '%descriptor_numeric%', 	COALESCE(descriptor_numeric::TEXT,'Unknown')),
	   '%descriptor_string%', 	COALESCE(descriptor_string,'Unknown')),
	  '%referencing_id%', 		COALESCE(referencing_id::TEXT,'Unknown')),
	 '%planet_name%', 		COALESCE(GET_PLANET_NAME(referencing_id),'Unknown')
	) into full_text
	FROM my_events INNER JOIN action on my_events.action=action.name 
	WHERE my_events.id=read_event_id; 

        RETURN full_text;
END
$read_event$ LANGUAGE plpgsql;

--Ok, doubling this isn't an elegant solution but we can clean it up.. later
--cleaning things up later actually happens right?
CREATE OR REPLACE FUNCTION READ_EVENT(read_round_id integer, read_event_id integer) RETURNS 
TEXT AS $read_event$
DECLARE
	full_text TEXT;
BEGIN
	-- Sometimes you just write some dirty code... 
	SELECT  
	replace(
	 replace(
	  replace(
	   replace(
	    replace(
	     replace(
	      replace(
	       replace(
	        replace(
	         replace(
	          replace(
	           replace(
	            replace(
	             replace(action.string,
	              '%player_id_1%', 	player_id_1::TEXT),
	             '%player_name_1%', GET_PLAYER_USERNAME(player_id_1)),
	            '%player_id_2%', 	COALESCE(player_id_2::TEXT,'Unknown')),
	           '%player_name_2%', 	COALESCE(GET_PLAYER_USERNAME(player_id_2),'Unknown')),
	          '%ship_id_1%', 	COALESCE(ship_id_1::TEXT,'Unknown')),
	         '%ship_id_2%', 	COALESCE(ship_id_2::TEXT,'Unknown')),
	        '%ship_name_1%', 	COALESCE(GET_SHIP_NAME(ship_id_1),'Unknown')),
	       '%ship_name_2%', 	COALESCE(GET_SHIP_NAME(ship_id_2),'Unknown')),
	      '%location_x%', 		COALESCE(location_x::TEXT,'Unknown')),
	     '%location_y%', 		COALESCE(location_y::TEXT,'Unknown')),
	    '%descriptor_numeric%', 	COALESCE(descriptor_numeric::TEXT,'Unknown')),
	   '%descriptor_string%', 	COALESCE(descriptor_string,'Unknown')),
	  '%referencing_id%', 		COALESCE(referencing_id::TEXT,'Unknown')),
	 '%planet_name%', 		COALESCE(GET_PLANET_NAME(referencing_id),'Unknown')
	) into full_text
	FROM event_archive INNER JOIN action on event_archive.action=action.name 
	WHERE event_archive.event_id=read_event_id AND event_archive.round=read_round_id; 

        RETURN full_text;
END
$read_event$ LANGUAGE plpgsql;


CREATE TABLE trade
(
	id integer NOT NULL PRIMARY KEY,
	player_id_1 integer NOT NULL REFERENCES player(id),
	player_id_2 integer NOT NULL REFERENCES player(id),
	confirmation_1 integer DEFAULT '0',
	confirmation_2 integer DEFAULT '0',
	complete boolean DEFAULT 'f'
);
CREATE SEQUENCE trade_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;

CREATE VIEW my_trades AS
SELECT * FROM trade WHERE GET_PLAYER_ID(SESSION_USER) IN (player_id_1, player_id_2);

CREATE RULE trade_insert AS ON INSERT TO my_trades 
	DO INSTEAD 
		INSERT INTO trade(player_id_1, player_id_2, confirmation_1, confirmation_2) 
		VALUES(NEW.player_id_1,NEW.player_id_2,NEW.confirmation_1,NEW.confirmation_2);


CREATE OR REPLACE FUNCTION CREATE_TRADE_EVENT() RETURNS trigger AS $create_trade_event$
BEGIN
	INSERT INTO event(action, player_id_1, player_id_2, referencing_id, public, tic)
		VALUES('TRADE_START',NEW.player_id_1, NEW.player_id_2 , NEW.id, 'f',(SELECT last_value FROM tic_seq));
        RETURN NULL;
END
$create_trade_event$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER CREATE_TRADE_EVENT AFTER INSERT ON trade
  FOR EACH ROW EXECUTE PROCEDURE CREATE_TRADE_EVENT();



CREATE RULE trade_update AS ON UPDATE TO my_trades 
	DO INSTEAD UPDATE trade 
		SET 
			player_id_1=NEW.player_id_1,
			player_id_2=NEW.player_id_2,
			confirmation_1=NEW.confirmation_1,
			confirmation_2=NEW.confirmation_2
		WHERE id=NEW.id;

CREATE RULE trade_delete AS ON DELETE TO my_trades
DO INSTEAD 
(
	DELETE FROM trade WHERE id=OLD.id;
);

CREATE OR REPLACE FUNCTION DELETE_TRADE_EVENT() RETURNS trigger AS $delete_trade_event$
BEGIN
	INSERT INTO event(action, player_id_1, player_id_2, referencing_id, public, tic)
		VALUES('TRADE_CANCEL',OLD.player_id_1, OLD.player_id_2 , OLD.id, 'f',(SELECT last_value FROM tic_seq));
        RETURN NULL;
END
$delete_trade_event$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER DELETE_TRADE_EVENT AFTER DELETE ON trade
  FOR EACH ROW EXECUTE PROCEDURE DELETE_TRADE_EVENT();



CREATE TABLE trade_item 
(
	id integer NOT NULL PRIMARY KEY,
	trade_id integer NOT NULL REFERENCES trade(id),
	player_id integer NOT NULL REFERENCES player(id) DEFAULT get_player_id(SESSION_USER),
	description_code character varying  NOT NULL,
	quantity integer,
	descriptor character varying
);

CREATE SEQUENCE trade_item_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;


CREATE VIEW trade_items AS
SELECT 
	trade_item.id as id,
	trade_item.trade_id as trade_id,
	trade_item.player_id as player_id,
	trade_item.description_code as description_code,
	trade_item.quantity as quantity,
	trade_item.descriptor as descriptor	
FROM  trade_item WHERE 
trade_id in (select id from trade where GET_PLAYER_ID(SESSION_USER) IN (trade.player_id_1, trade.player_id_2));

CREATE RULE trade_item_insert AS ON INSERT TO trade_items
        DO INSTEAD INSERT INTO trade_item(trade_id, player_id, description_code, quantity, descriptor)
                VALUES(NEW.trade_id,
                  NEW.player_id,
                  NEW.description_code,
                  NEW.quantity,
                  NEW.descriptor);

CREATE RULE trade_item_delete AS ON DELETE TO trade_items
        DO INSTEAD
		DELETE FROM trade_item WHERE id=OLD.id;
			

CREATE VIEW trade_ship_stats AS
SELECT 
	trade_item.id as id,
	trade_item.trade_id as trade_id,
	trade_item.player_id as player_id,
	trade_item.description_code as description_code,
	trade_item.quantity as quantity,
	trade_item.descriptor as descriptor,
	ship.id as ship_id,
	ship.name as ship_name,
	ship.current_health as ship_current_health,
	ship.max_health as ship_max_health,
	ship.current_fuel as ship_current_fuel,
	ship.max_fuel as ship_max_fuel,
	ship.max_speed as ship_max_speed,
	ship.range as ship_range,
	ship.attack as ship_attack,
	ship.defense as ship_defense,
	ship.engineering as ship_engineering,
	ship.prospecting as ship_prospecting,
	ship.location_x as ship_location_x,
	ship.location_y as ship_location_y
FROM trade, trade_item, ship WHERE 
GET_PLAYER_ID(SESSION_USER) IN (trade.player_id_1, trade.player_id_2)
AND
trade.id=trade_item.trade_id
AND
trade.complete='f'
AND
trade_item.description_code ='SHIP' 
AND
ship.id=CAST(trade_item.descriptor as integer);



CREATE OR REPLACE FUNCTION ADD_TRADE_ITEM() RETURNS trigger AS $add_trade_item$
DECLARE
	check_value integer;
	
	trader_1 integer;
	trader_2 integer;

	completed boolean;
BEGIN
	SELECT INTO trader_1, trader_2, completed player_id_1, player_id_2, complete  FROM trade WHERE id=NEW.trade_id;
	IF completed = 't' THEN
		EXECUTE 'NOTIFY ' || get_player_error_channel() ||', ''Trade #'||NEW.trade_id ||' is complete. Cannot make changes'';';
		RETURN NULL;
	END IF;

	UPDATE trade SET confirmation_1=0, confirmation_2=0 WHERE id=NEW.trade_id;

	
	IF NEW.description_code = 'FUEL' THEN
		SELECT fuel_reserve INTO check_value FROM player WHERE id=NEW.player_id;
		IF check_value > NEW.quantity THEN 
			UPDATE player SET fuel_reserve=fuel_reserve-NEW.quantity WHERE id = NEW.player_id;

			INSERT INTO event(action, player_id_1, player_id_2, referencing_id, descriptor_numeric, descriptor_string, public, tic)
				VALUES('TRADE_ADD_ITEM',trader_1, trader_2 , NEW.trade_id, NEW.quantity, NEW.description_code,'f',(SELECT last_value FROM tic_seq));

		ELSE
			EXECUTE 'NOTIFY ' || get_player_error_channel() ||', ''You cant add more fuel to a trade then you hold in your my_player.fuel_reserve'';';
			RETURN NULL;
		END IF;
	ELSEIF NEW.description_code = 'MONEY' THEN
		SELECT balance INTO check_value FROM player WHERE id=NEW.player_id;
		IF check_value > NEW.quantity THEN 
			UPDATE player SET fuel_balance=balance-NEW.quantity WHERE id = NEW.player_id;

			INSERT INTO event(action, player_id_1, player_id_2, referencing_id, descriptor_numeric, descriptor_string, public, tic)
				VALUES('TRADE_ADD_ITEM',trader_1, trader_2 , NEW.trade_id, NEW.quantity, NEW.description_code,'f',(SELECT last_value FROM tic_seq));

		ELSE
			 EXECUTE 'NOTIFY ' || get_player_error_channel() ||', ''You cant add more money to a trade then you hold in your my_player.balance'';';
			RETURN NULL;
		END IF;
	ELSEIF NEW.description_code = 'SHIP' THEN
		SELECT player_id INTO check_value FROM ship WHERE id=CAST(NEW.descriptor as integer) AND destroyed='f';
		IF check_value = NEW.player_id THEN 
			--player 0 = schemaverse 
			UPDATE ship SET player_id=0, fleet_id=NULL WHERE id=CAST(NEW.descriptor as integer);

			INSERT INTO event(action, player_id_1, player_id_2, referencing_id, ship_id_1,  public, tic)
				VALUES('TRADE_ADD_SHIP',trader_1, trader_2 , NEW.trade_id,  NEW.descriptor::integer,'f',(SELECT last_value FROM tic_seq));

		ELSE
			EXECUTE 'NOTIFY ' || get_player_error_channel() ||', ''Trading a ship you dont own is kind of a DM'';';
			RETURN NULL;
		END IF;
	ELSEIF NEW.description_code = 'ITEM' THEN
		SELECT quantity INTO check_value FROM player_inventory WHERE player_id=NEW.player_id AND item=NEW.descriptor;
		--i need to make sure have items wont make this choke
		IF check_value > NEW.quantity THEN 
			UPDATE player_inventory SET quantity=quantity-NEW.quantity WHERE item=NEW.descriptor and player_id = NEW.player_id;

			INSERT INTO event(action, player_id_1, player_id_2, referencing_id, descriptor_numeric, descriptor_string, public, tic)
				VALUES('TRADE_ADD_ITEM',trader_1, trader_2 , NEW.trade_id, NEW.quantity, NEW.descriptor,'f',(SELECT last_value FROM tic_seq));


		ELSE
			EXECUTE 'NOTIFY ' || get_player_error_channel() ||', ''You do not own enough of that item to add it'';';
			RETURN NULL;
		END IF;
	END IF;
	
	RETURN NEW;
END
$add_trade_item$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER INCLUDE_TRADE_ITEM BEFORE INSERT ON trade_item
  FOR EACH ROW EXECUTE PROCEDURE ADD_TRADE_ITEM(); 


CREATE OR REPLACE FUNCTION DELETE_TRADE_ITEM() RETURNS trigger AS $delete_trade_item$
DECLARE
	
	trader_1 integer;
	trader_2 integer;
	completed integer;

BEGIN
	SELECT INTO trader_1, trader_2, completed player_id_1, player_id_2, complete FROM trade WHERE id=OLD.trade_id;
	IF completed = 't' THEN
		EXECUTE 'NOTIFY ' || get_player_error_channel() ||', ''Trade #'||OLD.trade_id ||' is complete. Cannot make changes'';';
		RETURN NULL;
	END IF;


	UPDATE trade SET confirmation_1=0, confirmation_2=0 WHERE id=OLD.trade_id;

	IF OLD.description_code = 'FUEL' THEN
		UPDATE player SET fuel_reserve=fuel_reserve+OLD.quantity WHERE id = OLD.player_id;

		INSERT INTO event(action, player_id_1, player_id_2, referencing_id, descriptor_numeric, descriptor_string, public, tic)
			VALUES('TRADE_DELETE_ITEM',trader_1, trader_2 , OLD.trade_id, OLD.quantity, OLD.description_code,'f',(SELECT last_value FROM tic_seq));


	ELSEIF OLD.description_code = 'MONEY' THEN
		UPDATE player SET fuel_balance=balance+OLD.quantity WHERE id = OLD.player_id;
		INSERT INTO event(action, player_id_1, player_id_2, referencing_id, descriptor_numeric, descriptor_string, public, tic)
			VALUES('TRADE_DELETE_ITEM',trader_1, trader_2 , OLD.trade_id, OLD.quantity, OLD.description_code,'f',(SELECT last_value FROM tic_seq));


	ELSEIF OLD.description_code = 'SHIP' THEN
		UPDATE ship SET player_id=OLD.player_id, fleet_id=NULL WHERE id = CAST(OLD.descriptor as integer);

		INSERT INTO event(action, player_id_1, player_id_2, referencing_id, ship_id_1,  public, tic)
			VALUES('TRADE_DELETE_SHIP',trader_1, trader_2 , OLD.trade_id, OLD.descriptor::integer,'f',(SELECT last_value FROM tic_seq));

	ELSEIF OLD.description_code = 'ITEM' THEN
		INSERT INTO player_inventory(player_id, item, quantity) VALUES(OLD.player_id, OLD.descriptor, OLD.quantity); 
		INSERT INTO event(action, player_id_1, player_id_2, referencing_id, descriptor_numeric, descriptor_string, public, tic)
			VALUES('TRADE_DELETE_ITEM',trader_1, trader_2 , OLD.trade_id, OLD.quantity, OLD.descriptor,'f',(SELECT last_value FROM tic_seq));

	END IF;

	RETURN OLD;
END
$delete_trade_item$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER DELETE_TRADE_ITEM BEFORE DELETE ON trade_item
  FOR EACH ROW EXECUTE PROCEDURE DELETE_TRADE_ITEM(); 

CREATE OR REPLACE FUNCTION TRADE_CONFIRMATION() RETURNS trigger AS $trade_confirmation$
DECLARE 
	trade_items RECORD;
	recipient integer;
	giver integer;
	--hot

BEGIN
	IF NEW.complete = 'f' AND NEW.confirmation_1=NEW.player_id_1 AND NEW.confirmation_2=NEW.player_id_2 THEN
		FOR trade_items IN SELECT * FROM trade_item WHERE trade_id = NEW.id  LOOP 
	
			IF NEW.player_id_1 = trade_items.player_id THEN
				giver := NEW.player_id_1;
				recipient := NEW.player_id_2;
			ELSE
				giver := NEW.player_id_2;
				recipient := NEW.player_id_1;			
			END IF;

			IF trade_items.description_code = 'FUEL' THEN
				UPDATE player SET fuel_reserve=fuel_reserve+trade_items.quantity WHERE id = recipient;
			ELSEIF trade_items.description_code = 'MONEY' THEN
				UPDATE player SET fuel_balance=balance+trade_items.quantity WHERE id = recipient;
			ELSEIF trade_items.description_code = 'SHIP' THEN
				UPDATE ship SET player_id=recipient WHERE id=CAST(trade_items.descriptor as integer);
			ELSEIF trade_items.description_code = 'ITEM' THEN
				INSERT INTO player_inventory(player_id, item, quantity) VALUES(recipient, trade_items.descriptor, trade_items.quantity); 
			END IF;
		END LOOP;
		
		NEW.complete = 't';

		INSERT INTO event(action, player_id_1, player_id_2, referencing_id, public, tic)
			VALUES('TRADE_COMPLETE',NEW.player_id_1, NEW.player_id_2 , NEW.id,'f',(SELECT last_value FROM tic_seq));
                                                        
	END IF;

	IF NEW.complete='f' AND (NOT NEW.confirmation_1=OLD.confirmation_1) AND NEW.confirmation_1=NEW.player_id_1 THEN 
		INSERT INTO event(action, player_id_1, player_id_2, referencing_id, public, tic)
			VALUES('TRADE_CONFIRM',NEW.player_id_1, NEW.player_id_2 , NEW.id,'f',(SELECT last_value FROM tic_seq));
	ELSEIF  NEW.complete='f' AND (NOT NEW.confirmation_2=OLD.confirmation_2) AND NEW.confirmation_2=NEW.player_id_2 THEN
		INSERT INTO event(action, player_id_1, player_id_2, referencing_id, public, tic)
			VALUES('TRADE_CONFIRM',NEW.player_id_2, NEW.player_id_1 , NEW.id,'f',(SELECT last_value FROM tic_seq));
	END IF;

RETURN NEW;
END
$trade_confirmation$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER TRADE_CONFIRMATION BEFORE UPDATE ON trade
  FOR EACH ROW EXECUTE PROCEDURE TRADE_CONFIRMATION(); 


CREATE TABLE planet
(
	id integer NOT NULL PRIMARY KEY,
	name character varying,
	fuel integer NOT NULL DEFAULT RANDOM()*100000,
	mine_limit integer NOT NULL DEFAULT RANDOM()*100,
	difficulty integer NOT NULL DEFAULT RANDOM()*10,
	location_x integer NOT NULL DEFAULT RANDOM(),
	location_y integer NOT NULL DEFAULT RANDOM(),
	conqueror_id integer REFERENCES player(id)
);

CREATE SEQUENCE planet_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;

--The following will generate planets around the universe but is a bit sketch
--The given start and stop paramters will define where approximately planets will be generated
--The smaller the numbers given, the closer to the center planets will be created. 
create or replace function generate_planets(start integer, stop integer) returns boolean as $generate_planets$
declare
	new_planet record;
begin
	for new_planet in select
                nextval('planet_id_seq') as id,
                CASE generate_series * (RANDOM() * 11)::integer % 11
                  WHEN 0 THEN 'Aethra_' || generate_series
                         WHEN 1 THEN 'Mony_' || generate_series
                         WHEN 2 THEN 'Semper_' || generate_series
                         WHEN 3 THEN 'Voit_' || generate_series
                         WHEN 4 THEN 'Lester_' || generate_series 
                         WHEN 5 THEN 'Rio_' || generate_series 
                         WHEN 6 THEN 'Zergon_' || generate_series 
                         WHEN 7 THEN 'Cannibalon_' || generate_series
                         WHEN 8 THEN 'Omicron Persei_' || generate_series
                         WHEN 9 THEN 'Urectum_' || generate_series
                         WHEN 10 THEN 'Wormulon_' || generate_series
 			END as name,
                (RANDOM() * 100)::integer as mine_limit,
                (RANDOM() * 10)::integer as difficulty,
                CASE (RANDOM() * 10)::integer % 4
                        WHEN 0 THEN (RANDOM() * generate_series * 2000)::integer
                        WHEN 1 THEN (RANDOM() * generate_series * 2000 * -1)::integer 
                        WHEN 2 THEN (RANDOM() * generate_series)::integer
                        WHEN 3 THEN (RANDOM() * generate_series * -1)::integer
		END as location_x,
                CASE (RANDOM() * 10)::integer % 4
                        WHEN 0 THEN (RANDOM() * generate_series * 2000)::integer
                        WHEN 1 THEN (RANDOM() * generate_series * 2000 * -1)::integer 
		     	WHEN 2 THEN (RANDOM() * generate_series)::integer
                        WHEN 3 THEN (RANDOM() * generate_series * -1)::integer		
		END as location_y

        from generate_series(start,stop)
	LOOP
		IF NOT ((SELECT COUNT(id) FROM planet WHERE location_x between new_planet.location_x-3000 and new_planet.location_x+3000
						AND location_y between new_planet.location_y-3000 and new_planet.location_y+3000) > 0) THEN
			insert into planet(id, name, mine_limit, difficulty, location_x, location_y)
				VALUES(new_planet.id, new_planet.name, new_planet.mine_limit, new_planet.difficulty, new_planet.location_x, new_planet.location_y);
		END IF;	
	end loop;
	RETURN 't';
end
$generate_planets$ language plpgsql;


CREATE OR REPLACE FUNCTION GET_PLANET_NAME(planet_id integer) RETURNS character varying AS $get_planet_name$
DECLARE 
	found_planetname character varying;
BEGIN
	SELECT name INTO found_planetname FROM planet WHERE id=planet_id;
	RETURN found_planetname;
END
$get_planet_name$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE TABLE planet_miners
(
	planet_id integer REFERENCES planet(id) ON DELETE CASCADE,
	ship_id integer REFERENCES ship(id),
	PRIMARY KEY (planet_id, ship_id)
);


CREATE VIEW planets AS
SELECT 
	planet.id as id,
	planet.name as name,
	planet.mine_limit as mine_limit,
	planet.location_x as location_x,
	planet.location_y as location_y,
	planet.conqueror_id as conqueror_id 
FROM planet;

CREATE RULE planet_update AS ON UPDATE TO planets
        DO INSTEAD UPDATE planet SET name=NEW.name WHERE  planet.id <> 1 AND id=NEW.id AND conqueror_id=GET_PLAYER_ID(SESSION_USER);

CREATE OR REPLACE FUNCTION UPDATE_PLANET() RETURNS trigger as $update_planet$
BEGIN
	IF NEW.conqueror_id!=OLD.conqueror_id THEN
		INSERT INTO event(action, player_id_1, player_id_2, referencing_id, location_x, location_y, public, tic)
			VALUES('CONQUER',NEW.conqueror_id,OLD.conqueror_id, NEW.id , NEW.location_x, NEW.location_y, 't',(SELECT last_value FROM tic_seq));
	END IF;
	RETURN NEW;	
END
$update_planet$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER UPDATE_PLANET AFTER UPDATE ON planet
  FOR EACH ROW EXECUTE PROCEDURE UPDATE_PLANET();

create table trophy (
	id integer NOT NULL PRIMARY KEY,
	name character varying,
	description text,
	picture_link text,
	script text,
	script_declarations text,
	creator integer NOT NULL REFERENCES player(id), 
	approved boolean default 'f',
	round_started integer
);

CREATE SEQUENCE trophy_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;


CREATE OR REPLACE FUNCTION CREATE_TROPHY() RETURNS trigger AS $create_trophy$
BEGIN
     
	NEW.approved 	:= 'f';
	NEW.creator 	:= GET_PLAYER_ID(SESSION_USER);
	NEW.round_started := 0;

       RETURN NEW;
END
$create_trophy$ LANGUAGE plpgsql;


CREATE TRIGGER CREATE_TROPHY BEFORE INSERT ON trophy
  FOR EACH ROW EXECUTE PROCEDURE CREATE_TROPHY();

CREATE TYPE trophy_winner AS (round integer, trophy_id integer, player_id integer);

CREATE OR REPLACE FUNCTION TROPHY_SCRIPT_UPDATE() RETURNS trigger AS $trophy_script_update$
DECLARE
       current_round integer;
	secret character varying;

	player_id integer;
BEGIN

	player_id := GET_PLAYER_ID(SESSION_USER);

	IF  SESSION_USER = 'schemaverse' THEN
	       IF NEW.approved='t' AND OLD.approved='f' THEN
			IF NEW.round_started=0 THEN
				SELECT last_value INTO NEW.round_started FROM round_seq;
			END IF;

		        secret := 'trophy_script_' || (RANDOM()*1000000)::integer;
       		 EXECUTE 'CREATE OR REPLACE FUNCTION TROPHY_SCRIPT_'|| NEW.id ||'() RETURNS SETOF trophy_winner AS $'||secret||'$
		        DECLARE
				this_trophy_id integer;
				this_round integer;
				  winner trophy_winner%rowtype;
       		         ' || NEW.script_declarations || '
		        BEGIN
       		         this_trophy_id := '|| NEW.id||';
       		         SELECT last_value INTO this_round FROM round_seq; 
	       	         ' || NEW.script || '
			 RETURN;
	       	 END $'||secret||'$ LANGUAGE plpgsql;'::TEXT;

		 EXECUTE 'REVOKE ALL ON FUNCTION TROPHY_SCRIPT_'|| NEW.id ||'() FROM PUBLIC'::TEXT;
       		 EXECUTE 'REVOKE ALL ON FUNCTION TROPHY_SCRIPT_'|| NEW.id ||'() FROM players'::TEXT;
		 EXECUTE 'GRANT EXECUTE ON FUNCTION TROPHY_SCRIPT_'|| NEW.id ||'() TO schemaverse'::TEXT;
		END IF;
	ELSEIF NOT player_id = OLD.creator THEN
		RETURN OLD;
	ELSE 
		IF NOT OLD.approved = NEW.approved THEN
			NEW.approved='f';
		END IF;

		IF NOT ((NEW.script = OLD.script) AND (NEW.script_declarations = OLD.script_declarations)) THEN
			NEW.approved='f';	         
	       END IF;
	END IF;

       RETURN NEW;
END $trophy_script_update$ LANGUAGE plpgsql;


CREATE TRIGGER TROPHY_SCRIPT_UPDATE BEFORE UPDATE ON trophy
  FOR EACH ROW EXECUTE PROCEDURE TROPHY_SCRIPT_UPDATE();

--Example Trophy
--insert into trophy(name, script,script_declaration) values ('The Participation Award' ,'FOR res IN SELECT id from player LOOP winner.round:=this_round; winner.trophy_id := this_trophy_id; winner.player_id := res.id; RETURN NEXT winner;END LOOP;', 'res RECORD;');

create table player_trophy (
	round integer,
	trophy_id integer NOT NULL REFERENCES trophy(id),
	player_id integer NOT NULL REFERENCES player(id), 
	PRIMARY KEY(round, trophy_id, player_id)
);

--How to award trophies
--INSERT INTO player_trophy SELECT * FROM trophy_script_#();

create view trophy_case as
SELECT  
	player_id, 
	GET_PLAYER_USERNAME(player_id) as username, 
	name as trophy, 
	count(trophy_id) as times_awarded,
	(SELECT round FROM player_trophy t where t.trophy_id=player_trophy.trophy_id  and t.player_id=player_trophy.player_id order by round desc LIMIT 1) as last_round_won
 FROM trophy, player_trophy
WHERE trophy.id=player_trophy.trophy_id
GROUP BY trophy_id, name, player_id;


-- This trigger forces complete control over ID's to this one function. 
-- Preventing any user form updating an ID or inserting an ID out of sequence
CREATE OR REPLACE FUNCTION ID_DEALER() RETURNS trigger AS $id_dealer$
BEGIN

	IF (TG_OP = 'INSERT') THEN 
		NEW.id = nextval(TG_TABLE_NAME || '_id_seq');
	ELSEIF (TG_OP = 'UPDATE') THEN
		NEW.id = OLD.id;
	END IF;
RETURN NEW;
END
$id_dealer$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER PLAYER_ID_DEALER BEFORE INSERT OR UPDATE ON player
  FOR EACH ROW EXECUTE PROCEDURE ID_DEALER(); 

CREATE TRIGGER SHIP_ID_DEALER BEFORE INSERT OR UPDATE ON ship
  FOR EACH ROW EXECUTE PROCEDURE ID_DEALER(); 

CREATE TRIGGER FLEET_ID_DEALER BEFORE INSERT OR UPDATE ON fleet
  FOR EACH ROW EXECUTE PROCEDURE ID_DEALER(); 

CREATE TRIGGER TRADE_ID_DEALER BEFORE INSERT OR UPDATE ON trade
  FOR EACH ROW EXECUTE PROCEDURE ID_DEALER(); 

CREATE TRIGGER TRADE_ID_DEALER BEFORE INSERT OR UPDATE ON trade_item
  FOR EACH ROW EXECUTE PROCEDURE ID_DEALER(); 

CREATE TRIGGER EVENT_LOG_ID_DEALER BEFORE INSERT OR UPDATE ON event
  FOR EACH ROW EXECUTE PROCEDURE ID_DEALER(); 

CREATE TRIGGER TROPHY_ID_DEALER BEFORE INSERT OR UPDATE ON trophy
  FOR EACH ROW EXECUTE PROCEDURE ID_DEALER();

--Permission verification


CREATE OR REPLACE FUNCTION GENERAL_PERMISSION_CHECK() RETURNS trigger AS $general_permission_check$
DECLARE
        real_player_id integer;
        checked_player_id integer;
BEGIN
        IF SESSION_USER = 'schemaverse' THEN
                RETURN NEW;
        ELSEIF CURRENT_USER = 'schemaverse' THEN
                SELECT id INTO real_player_id FROM player WHERE username=SESSION_USER;

                IF TG_TABLE_NAME IN ('ship','fleet','trade_item') THEN
                        IF (TG_OP = 'DELETE') THEN
				RETURN OLD;
			ELSE 
			 	RETURN NEW;
			END IF;
                ELSEIF TG_TABLE_NAME = 'trade' THEN
                        IF TG_OP = 'UPDATE' THEN
                                IF (OLD.player_id_1 != NEW.player_id_1) OR (OLD.player_id_2 != NEW.player_id_2) THEN
                                        RETURN NULL;
                                END IF;
                                IF NEW.confirmation_1 != OLD.confirmation_1 AND NEW.player_id_1 != real_player_id THEN
                                        RETURN NULL;
                                END IF;
                                IF NEW.confirmation_2 != OLD.confirmation_2 AND NEW.player_id_2 != real_player_id THEN
                                        RETURN NULL;
                                END IF;
                        ELSEIF TG_OP = 'DELETE' THEN
	                         IF real_player_id in (OLD.player_id_1, OLD.player_id_2) THEN
					RETURN OLD;
				ELSE 
					RETURN NULL;
				END IF;
			END IF;
			
                         IF real_player_id in (NEW.player_id_1, NEW.player_id_2) THEN
                                RETURN NEW;
                        END IF;
                ELSEIF TG_TABLE_NAME in ('ship_control') THEN
                        IF TG_OP = 'UPDATE' THEN
                                IF OLD.ship_id != NEW.ship_id THEN
                                        RETURN NULL;
				  END IF;
                        END IF;
                        SELECT player_id INTO checked_player_id FROM ship WHERE id=NEW.ship_id;
                        IF real_player_id = checked_player_id THEN
                                RETURN NEW;
                        END IF;
                END IF;

        ELSE

                SELECT id INTO real_player_id FROM player WHERE username=SESSION_USER;

                IF TG_TABLE_NAME IN ('ship','fleet','trade_item') THEN
                        IF TG_OP = 'UPDATE' THEN
                                IF OLD.player_id != NEW.player_id THEN
                                        RETURN NULL;
                                END IF;
                        END IF;
                        NEW.player_id = real_player_id;
                        RETURN NEW;

                ELSEIF TG_TABLE_NAME = 'trade' THEN
                        IF TG_OP = 'UPDATE' THEN
                                IF (OLD.player_id_1 != NEW.player_id_1) OR (OLD.player_id_2 != NEW.player_id_2) THEN
                                        RETURN NULL;
                                END IF;
                                IF NEW.confirmation_1 != OLD.confirmation_1 AND NEW.player_id_1 != real_player_id THEN
                                        RETURN NULL;
                                END IF;
                                IF NEW.confirmation_2 != OLD.confirmation_2 AND NEW.player_id_2 != real_player_id THEN
                                        RETURN NULL;
                                END IF;
                        END IF;
                         IF real_player_id in (NEW.player_id_1, NEW.player_id_2) THEN
                                RETURN NEW;
                        END IF;
                ELSEIF TG_TABLE_NAME in ('ship_control') THEN
                        IF TG_OP = 'UPDATE' THEN
                                IF OLD.ship_id != NEW.ship_id THEN
                                        RETURN NULL;
				  END IF;
                        END IF;
                        SELECT player_id INTO checked_player_id FROM ship WHERE id=NEW.ship_id;
                        IF real_player_id = checked_player_id THEN
                                RETURN NEW;
                        END IF;
                END IF;
        END IF;
        RETURN NULL;
END
$general_permission_check$ LANGUAGE plpgsql SECURITY DEFINER;


--All start with the letter 'A' so that this check runs before everything else. 
--This should prevent users from forcing charges to another users account

CREATE TRIGGER A_SHIP_PERMISSION_CHECK BEFORE INSERT OR UPDATE ON ship
  FOR EACH ROW EXECUTE PROCEDURE GENERAL_PERMISSION_CHECK(); 

CREATE TRIGGER A_SHIP_CONTROL_PERMISSION_CHECK BEFORE INSERT OR UPDATE OR DELETE ON ship_control
  FOR EACH ROW EXECUTE PROCEDURE GENERAL_PERMISSION_CHECK(); 

CREATE TRIGGER A_FLEET_PERMISSION_CHECK BEFORE INSERT OR UPDATE OR DELETE ON fleet
  FOR EACH ROW EXECUTE PROCEDURE GENERAL_PERMISSION_CHECK(); 

CREATE TRIGGER A_TRADE_PERMISSION_CHECK BEFORE INSERT OR UPDATE OR DELETE ON trade
  FOR EACH ROW EXECUTE PROCEDURE GENERAL_PERMISSION_CHECK(); 

CREATE TRIGGER A_TRADE_ITEM_PERMISSION_CHECK BEFORE INSERT OR DELETE ON trade_item
  FOR EACH ROW EXECUTE PROCEDURE GENERAL_PERMISSION_CHECK(); 



CREATE OR REPLACE FUNCTION ACTION_PERMISSION_CHECK(ship_id integer) RETURNS boolean AS $action_permission_check$
DECLARE 
	ships_player_id integer;
BEGIN
	SELECT player_id into ships_player_id FROM ship WHERE id=ship_id and destroyed='f' and current_health > 0 and last_action_tic != (SELECT last_value FROM tic_seq);
	IF ships_player_id = GET_PLAYER_ID(SESSION_USER) OR SESSION_USER = 'schemaverse' 
			OR CURRENT_USER = 'schemaverse'  THEN
		RETURN 't';
	ELSE 
		RETURN 'f';
	END IF;
END
$action_permission_check$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION MOVE_PERMISSION_CHECK(ship_id integer) RETURNS boolean AS $move_permission_check$
DECLARE 
	ships_player_id integer;
	last_tic integer;
BEGIN
	SELECT player_id, last_move_tic into ships_player_id, last_tic FROM ship WHERE id=ship_id and current_health > 0 and destroyed='f';
	IF  last_tic != (SELECT last_value FROM tic_seq) 
		AND ( 
			ships_player_id = GET_PLAYER_ID(SESSION_USER) 
			OR SESSION_USER = 'schemaverse' 
			OR CURRENT_USER = 'schemaverse' 
		 ) THEN
		RETURN 't';
	ELSE 
		RETURN 'f';
	END IF;
END
$move_permission_check$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION IN_RANGE_SHIP(ship_1 integer, ship_2 integer) RETURNS boolean AS $in_range_ship$
DECLARE
	check_count integer;
BEGIN
	SELECT 
		count(enemies.id)
	INTO check_count
	FROM ship enemies, ship players
	WHERE 	
		enemies.destroyed='f' AND players.destroyed='f'
		AND
		(
			players.id=ship_1
			AND 
			enemies.id=ship_2
 		) 
		AND
		(
			(enemies.location_x between (players.location_x-players.range) and (players.location_x+players.range)) 
			AND
			(enemies.location_y between (players.location_y-players.range) and (players.location_y+players.range)) 
		);
	IF check_count = 1 THEN
		RETURN 't';
	ELSE
		RETURN 'f';
	END IF;
END
$in_range_ship$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION IN_RANGE_PLANET(ship_id integer, planet_id integer) RETURNS boolean AS $in_range_planet$
DECLARE
	check_count integer;
BEGIN
	SELECT 
		count(planet.id)
	INTO check_count
	FROM planet, ship
	WHERE 	ship.destroyed='f'
		AND
		(
			ship.id=ship_id
			AND 
			planet.id=planet_id
 		) 
		AND
		(
			(planet.location_x between (ship.location_x-ship.range) and (ship.location_x+ship.range)) 
			AND
			(planet.location_y between (ship.location_y-ship.range) and (ship.location_y+ship.range)) 
		);
	IF check_count = 1 THEN
		RETURN 't';
	ELSE
		RETURN 'f';
	END IF;
END
$in_range_planet$ LANGUAGE plpgsql SECURITY DEFINER;

-- Action methods
CREATE OR REPLACE FUNCTION Attack(attacker integer, enemy_ship integer) RETURNS integer AS $attack$
DECLARE
	damage integer;
	attack_rate integer;
	defense_rate integer;
	attacker_name character varying;
	attacker_player_id integer;
	enemy_name character varying;
	enemy_player_id integer;
	defense_efficiency numeric;
	loc_x integer;
	loc_y integer;

BEGIN
	
	damage = 0;
	
	
	--check range
	IF ACTION_PERMISSION_CHECK(attacker) AND (IN_RANGE_SHIP(attacker, enemy_ship)) THEN
	
		defense_efficiency := GET_NUMERIC_VARIABLE('DEFENSE_EFFICIENCY') / 100::numeric;
		
		--FINE, I won't divide by zero
		SELECT attack + 1, player_id, name, location_x, location_y INTO attack_rate, attacker_player_id, attacker_name, loc_x, loc_y FROM ship WHERE id=attacker;
		SELECT defense + 1, player_id, name INTO defense_rate, enemy_player_id, enemy_name FROM ship WHERE id=enemy_ship;
	

		damage = (attack_rate * (defense_efficiency/defense_rate+defense_efficiency))::integer;		
		UPDATE ship SET future_health=future_health-damage WHERE id=enemy_ship;
		UPDATE ship SET last_action_tic=(SELECT last_value FROM tic_seq) WHERE id=attacker;
		
		INSERT INTO event(action, player_id_1,ship_id_1, player_id_2, ship_id_2, descriptor_numeric, location_x,location_y, public, tic)
			VALUES('ATTACK',attacker_player_id, attacker, enemy_player_id, enemy_ship , damage, loc_x, loc_y, 't',(SELECT last_value FROM tic_seq));
	ELSE 
		 EXECUTE 'NOTIFY ' || get_player_error_channel() ||', ''Attack from ' || attacker || ' to '|| enemy_ship ||' failed'';';
	END IF;	

	RETURN damage;
END
$attack$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION Repair(repair_ship integer, repaired_ship integer) RETURNS integer AS $repair$
DECLARE

	repair_rate integer;
	repair_ship_name character varying;
	repair_ship_player_id integer;
	repaired_ship_name character varying;
	
	loc_x integer;
	loc_y integer;
BEGIN
	
	repair_rate = 0;
	
	
	--check range
	IF ACTION_PERMISSION_CHECK(repair_ship) AND (IN_RANGE_SHIP(repair_ship, repaired_ship)) THEN
	
		SELECT engineering, player_id, name, location_x, location_y INTO repair_rate, repair_ship_player_id, repair_ship_name, loc_x, loc_y FROM ship WHERE id=repair_ship;
		SELECT name INTO repaired_ship_name FROM ship WHERE id=repaired_ship;
		UPDATE ship SET future_health = future_health + repair_rate WHERE id=repaired_ship;
		UPDATE ship SET last_action_tic=(SELECT last_value FROM tic_seq) WHERE id=repair_ship;
		
		INSERT INTO event(action, player_id_1,ship_id_1, ship_id_2, descriptor_numeric, location_x,location_y, public, tic)
			VALUES('REPAIR',repair_ship_player_id, repair_ship,  repaired_ship , repair_rate,loc_x,loc_y,'t',(SELECT last_value FROM tic_seq));

	ELSE 
		 EXECUTE 'NOTIFY ' || get_player_error_channel() ||', ''Repair from ' || repair_ship || ' to '|| repaired_ship ||' failed'';';
	END IF;	

	RETURN repair_rate;
END
$repair$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION Mine(ship_id integer, planet_id integer) RETURNS boolean AS $mine$
BEGIN
	IF ACTION_PERMISSION_CHECK(ship_id) AND (IN_RANGE_PLANET(ship_id, planet_id)) THEN
		INSERT INTO planet_miners VALUES(planet_id, ship_id);
		UPDATE ship SET last_action_tic=(SELECT last_value FROM tic_seq) WHERE id=ship_id;
		RETURN 't';
	ELSE
		EXECUTE 'NOTIFY ' || get_player_error_channel() ||', ''Mining ' || planet_id || ' with ship '|| ship_id ||' failed'';';
		RETURN 'f';
	END IF;

END
$mine$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION Perform_Mining() RETURNS integer as $perform_mining$
DECLARE
	miners RECORD;
	current_planet_id integer;
	current_planet_limit integer;
	current_planet_difficulty integer;
	current_planet_fuel integer;
	limit_counter integer;
	mined_player_fuel integer;

	new_fuel_reserve bigint;
	 
BEGIN
	current_planet_id = 0; 
	FOR miners IN SELECT 
			planet_miners.planet_id as planet_id, 
			planet_miners.ship_id as ship_id, 
			ship.player_id as player_id, 
			ship.prospecting as prospecting,
			ship.location_x as location_x,
			ship.location_y as location_y,
			player.fuel_reserve as fuel_reserve
			FROM 
				planet_miners, ship, player
			WHERE
				planet_miners.ship_id=ship.id
					AND player.id=ship.player_id
			ORDER BY planet_miners.planet_id, (ship.prospecting * RANDOM()) LOOP 
		
		IF current_planet_id != miners.planet_id THEN
			limit_counter := 0;
			current_planet_id := miners.planet_id;
			SELECT INTO current_planet_fuel, current_planet_difficulty, current_planet_limit fuel, difficulty, mine_limit FROM planet WHERE id=current_planet_id;
		END IF;
		
		--Added current_planet_fuel check here to fix negative fuel_reserve
		IF limit_counter < current_planet_limit AND current_planet_fuel > 0 THEN
			mined_player_fuel := (GET_NUMERIC_VARIABLE('MINE_BASE_FUEL') * RANDOM() * miners.prospecting * current_planet_difficulty)::integer;
			IF mined_player_fuel > current_planet_fuel THEN 
				mined_player_fuel = current_planet_fuel;
			END IF;

			IF mined_player_fuel <= 0 THEN
				INSERT INTO event(action, player_id_1,ship_id_1, referencing_id, location_x,location_y, public, tic)
					VALUES('MINE_FAIL',miners.player_id, miners.ship_id, miners.planet_id, miners.location_x,miners.location_y,'f',(SELECT last_value FROM tic_seq));		
			ELSE 
				SELECT INTO new_fuel_reserve fuel_reserve + mined_player_fuel FROM player WHERE id=miners.player_id;
				IF new_fuel_reserve > 2147483647 THEN
					mined_player_fuel := 2147483647 - miners.fuel_reserve; 
					new_fuel_reserve := 2147483647;
				END IF;

				current_planet_fuel := current_planet_fuel - mined_player_fuel;


				UPDATE player SET fuel_reserve = (new_fuel_reserve)::integer WHERE id = miners.player_id;
				UPDATE planet SET fuel = (fuel - mined_player_fuel)::integer WHERE id = current_planet_id;

				INSERT INTO event(action, player_id_1,ship_id_1, referencing_id, descriptor_numeric, location_x,location_y, public, tic)
					VALUES('MINE_SUCCESS',miners.player_id, miners.ship_id, miners.planet_id , mined_player_fuel,miners.location_x,miners.location_y,'t',(SELECT last_value FROM tic_seq));
			END IF;
			limit_counter = limit_counter + 1;
		ELSE
			--INSERT INTO event(action, player_id_1,ship_id_1, referencing_id, location_x,location_y, public, tic)
			--	VALUES('MINE_FAIL',miners.player_id, miners.ship_id, miners.planet_id, miners.location_x,miners.location_y,'f',(SELECT last_value FROM tic_seq));
		END IF;		
		DELETE FROM planet_miners WHERE planet_id=miners.planet_id AND ship_id=miners.ship_id;
	END LOOP;

	current_planet_id = 0; 
	FOR miners IN SELECT count(event.player_id_1) as mined, event.referencing_id as planet_id, event.player_id_1 as player_id, 
			CASE WHEN (select conqueror_id from planet where id=event.referencing_id)=event.player_id_1 THEN 2 ELSE 1 END as current_conqueror
			FROM event
			WHERE event.action='MINE_SUCCESS' AND event.tic=(SELECT last_value FROM tic_seq)
			GROUP BY event.referencing_id, event.player_id_1
			ORDER BY planet_id, mined DESC, current_conqueror DESC LOOP

		IF current_planet_id != miners.planet_id THEN
			current_planet_id := miners.planet_id;
			IF miners.current_conqueror=1 THEN
				UPDATE 	planet 	SET conqueror_id=miners.player_id WHERE planet.id=miners.planet_id;
			END IF;
		END IF;
	END LOOP;
	RETURN 1;
END
$perform_mining$ LANGUAGE plpgsql;

-- Contribution from Tigereye
-- Helper function for making MOVE() actually work
CREATE OR REPLACE FUNCTION getangle(current_x integer, current_y integer, new_destination_x integer, new_destination_y integer)
  RETURNS integer AS
$BODY$
DECLARE
        distance_x integer;
        distance_y integer;
        angle integer = 0;
BEGIN
        distance_x := (new_destination_x - current_x);
        distance_y := (new_destination_y - current_y);
        
        IF (distance_x <> 0 OR distance_y <> 0) THEN
	    angle = CAST(DEGREES(ATAN2(distance_y, distance_x)) AS integer);
        
            IF (angle < 0) THEN
                angle := angle + 360;
            END IF;
        END IF;
        
        RETURN angle;
END;
$BODY$
  LANGUAGE plpgsql; 


-- This function has been altered a bunch recently. Check out Issue 7 on github for more details about the changes
-- https://github.com/Abstrct/Schemaverse/issues/7
CREATE OR REPLACE FUNCTION "move"(moving_ship_id integer, new_speed integer, new_direction integer, new_destination_x integer, new_destination_y integer)
  RETURNS boolean AS
$MOVE$
DECLARE
        max_speed integer;
        current_speed integer;
        current_fuel integer;
        current_direction integer;
        fuel_cost integer;
        direction_fuel_cost integer := 0;
        final_speed integer;
        final_direction  integer;
        final_fuel integer;
        distance  bigint;
        distance_x bigint;
        distance_y bigint;
        range integer;
        location_x  integer;
        location_y  integer;
        ship_player_id integer;
BEGIN
        -- Grab current stats of ship
        SELECT INTO max_speed, current_fuel, location_x, location_y, ship_player_id  ship.max_speed, ship.current_fuel, ship.location_x, ship.location_y, player_id from ship WHERE id=moving_ship_id;
        SELECT INTO current_speed, current_direction speed, direction FROM ship_control WHERE ship_id = moving_ship_id;
                
        IF MOVE_PERMISSION_CHECK(moving_ship_id) THEN
                -- If they don't know what direction they're going, calculate it for them
                IF (new_direction IS NULL) THEN
                    final_direction := getangle(location_x, location_y, new_destination_x, new_destination_y);
                ELSE
                    final_direction := MOD(new_direction, 360);
                END IF;
                
		--If there is no speed given (NULL), check for the best speed to travel at that will still allow for stopping
		IF (new_speed IS NULL) THEN
                    new_speed :=  LEAST(max_speed, CASE WHEN current_speed=0 THEN (current_fuel/2) ELSE (current_fuel/2)-180 END );
                END IF;

		IF new_speed < 0 THEN
			new_speed = 0;
		END IF;

                -- Make sure they don't travel faster than max_speed!
                SELECT INTO final_speed CASE WHEN new_speed < max_speed THEN new_speed ELSE max_speed END;
                
                -- Calculate the distance to target (if it exists)
                IF (new_destination_x IS NOT NULL AND new_destination_y IS NOT NULL) THEN
                    distance_x := new_destination_x - location_x;
                    distance_y := new_destination_y - location_y;
                    distance := CAST(SQRT((distance_x * distance_x) + (distance_y * distance_y)) AS bigint);
                    
                    -- If their distance is less than their speed, override it
                    IF (distance < final_speed) THEN
                        IF (distance < 2147483647) THEN
                            distance = CAST(distance AS integer);
                        ELSE
                            distance := 2147483647;
                        END IF;
                    END IF;
                END IF;
                
                -- If they're not currently travelling at this speed/direction...
                IF (current_speed <> final_speed OR current_direction <> final_direction) THEN
                    fuel_cost := ABS(final_speed - current_speed); -- Calculate the fuel cost to change speed
                    
                    -- if they're already moving and aren't trying to stop...
                    IF (current_speed <> 0 AND final_speed <> 0) THEN -- add 1 fuel cost per degree changed
                        direction_fuel_cost := least(ABS(final_direction - current_direction), ABS(360 + current_direction - final_direction));
                        -- Pythagorus is inexact with integer-only datatypes, so sometimes we're off by 1 degree when calculating the direction.
                        -- Don't let this eat up our fuel!
                        IF (direction_fuel_cost = 1) THEN direction_fuel_cost := 0; END IF;

                        fuel_cost := fuel_cost + direction_fuel_cost;
                    END IF;
                ELSE
                    fuel_cost := 0;
                END IF;

                -- Abort moving if they specified a destination and don't have enough fuel to get/stop there
                IF ((new_destination_x IS NOT NULL AND new_destination_y IS NOT NULL) AND (current_fuel < fuel_cost + direction_fuel_cost + final_speed)) THEN
                    EXECUTE 'NOTIFY ' || get_player_error_channel(GET_PLAYER_USERNAME(ship_player_id)) || ', ''' || moving_ship_id || ' does not have enough fuel to fly heading ' || final_direction || ', accelerate to ' || final_speed ||' and then stop! To override, specify a NULL destination x and y.'';';
                    RETURN 'f';
                END IF;
                
                final_fuel := current_fuel - fuel_cost;
                --EXECUTE 'NOTIFY ' || get_player_error_channel(GET_PLAYER_USERNAME(ship_player_id)) || ', ''Ship:' || moving_ship_id || '. Fuel:' || current_fuel || '. Cost:' || fuel_cost || '. DirCost:' || direction_fuel_cost || '. finalspeed: ' || final_speed || ''';';
                
                -- Move the ship!
                UPDATE
                        ship
                SET
                        current_fuel = final_fuel,
                        location_x = ship.location_x + CAST(COS(RADIANS(final_direction)) * final_speed AS integer),
                        location_y = ship.location_y + CAST(SIN(RADIANS(final_direction)) * final_speed AS integer),
                        last_move_tic = (SELECT last_value FROM tic_seq)
                WHERE
                        id = moving_ship_id;
                
                -- Update ship_control so future ticks know how to move this ship
                UPDATE 
                        ship_control 
                SET 
                        destination_x=new_destination_x, 
                        destination_y=new_destination_y,
                        speed=new_speed,
                        direction=final_direction
                WHERE 
                        ship_id = moving_ship_id;
                

                -- Re-retrieve the current ship stats
                SELECT INTO max_speed, current_fuel, location_x, location_y, range, ship_player_id  ship.max_speed, ship.current_fuel, ship.location_x, ship.location_y, ship.range, player_id FROM ship WHERE id=moving_ship_id;
                SELECT INTO current_speed, current_direction speed, direction FROM ship_control WHERE ship_id = moving_ship_id;
 
                -- If the ship is in range of its target..
                IF (new_destination_x IS NOT NULL AND new_destination_y IS NOT NULL) THEN
                IF (new_destination_x BETWEEN (location_x - range) AND (location_x + range) AND new_destination_y BETWEEN (location_y - range) AND (location_y + range)) THEN
                    -- calculate how much fuel it would require to stop (or slow down as much as possible)
                    IF (current_fuel >= current_speed) THEN
                        final_fuel := current_fuel - current_speed;
                        final_speed := 0;
                       final_direction := 0;
                    ELSE
                        final_fuel := 0;
                        final_speed := current_speed - current_fuel;
                        final_direction := current_direction;
                    END IF;
                    
                    -- Update the control and ship tables with the stopping results
                    UPDATE ship_control
                    SET speed = final_speed,
                    direction = final_direction
                    WHERE ship_id = moving_ship_id;
 
                    UPDATE ship
                    SET current_fuel = final_fuel
                    WHERE id = moving_ship_id;
                END IF;
                END IF;

                RETURN 't';
        ELSE
                EXECUTE 'NOTIFY ' || get_player_error_channel(GET_PLAYER_USERNAME(ship_player_id)) ||', ''Ship '|| moving_ship_id || ' did not budge!'';';
                RETURN 'f';
        END IF;
END
$MOVE$
  LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION "move"(moving_ship_id integer, new_destination_x integer, new_destination_y integer) RETURNS boolean AS 
$BODY$
BEGIN
	RETURN MOVE(moving_ship_id, NULL, NULL, new_destination_x, new_destination_y);
END
$BODY$
  LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION "move"(moving_ship_id integer, new_speed integer, new_destination_x integer, new_destination_y integer) RETURNS boolean AS 
$BODY$
BEGIN
	RETURN MOVE(moving_ship_id, new_speed, NULL, new_destination_x, new_destination_y);
END
$BODY$
  LANGUAGE plpgsql VOLATILE SECURITY DEFINER;


CREATE TABLE stat_log
(
	round integer NOT NULL, 
	tic integer NOT NULL,
	total_players integer,
	online_players integer,
	total_ships integer,
	avg_ships integer,
	total_trades integer,
	active_trades integer,
	total_fuel_reserve bigint,
	avg_fuel_reserve integer,
	total_currency bigint,
	avg_balance integer,
	CONSTRAINT stat_log_archive_pkey PRIMARY KEY (round, tic)	
);


CREATE VIEW current_stats AS
select 
	(SELECT last_value FROM round_seq) as current_round,
	(SELECT last_value FROM tic_seq) as current_tic,
	count(id) as total_players, 
	(select count(id) from online_players) as online_players,
	(SELECT count(id) from ship) as total_ships, 
	ceil(avg((SELECT count(id) from ship where player_id=player.id group by player_id))) as avg_ships, 
	(select count(id) from trade) as total_trades,
	(select count(id) from trade where player_id_1!=confirmation_1 OR player_id_2!=confirmation_2) as active_trades,
	(select sum(fuel_reserve) from player where id!=0) as total_fuel_reserves,
	ceil((select avg(fuel_reserve) from player where id!=0)) as avg_fuel_reserve,
	(select sum(balance) from player where id!=0) as total_currency,
	ceil((select avg(balance) from player where id!=0)) as avg_balance
from player ;

CREATE OR REPLACE VIEW current_player_stats AS
select
	player.id as player_id,
	player.username as username,
        (CASE WHEN (select count(id) from online_players where online_players.id=player.id) = 1 THEN true ELSE false END) as online,
        (SELECT count(id) from ship where player_id=player.id and destroyed='f') as alive_ships,
        (SELECT count(id) from ship where player_id=player.id and destroyed='t') as destroyed_ships,
        (select count(id) from trade where player.id in (player_id_1, player_id_2) ) as total_trades,
        (select count(id) from trade where player_id_1!=confirmation_1 OR player_id_2!=confirmation_2) as active_trades,
        player.fuel_reserve as fuel_reserves,
        player.balance as currency_balance,
        (SELECT count(id) from planet WHERE conqueror_id=player.id) as conquered_planets
from player;

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     
-- Create group 'players' and define the permissions

CREATE GROUP players WITH NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT;
REVOKE SELECT ON pg_proc FROM public;
REVOKE SELECT ON pg_proc FROM players;
REVOKE create ON schema public FROM public; 
REVOKE create ON schema public FROM players;

REVOKE ALL ON tic_seq FROM players;
GRANT SELECT ON tic_seq TO players;

REVOKE ALL ON round_seq FROM players;
GRANT SELECT ON round_seq TO players;

REVOKE ALL ON variable FROM players;
GRANT SELECT ON public_variable TO players;
GRANT INSERT ON public_variable TO players;
GRANT UPDATE ON public_variable TO players;
GRANT DELETE ON public_variable TO players;

REVOKE ALL ON item FROM players;
REVOKE ALL ON item_location FROM players;
GRANT SELECT ON item TO players;
GRANT INSERT ON item TO players;
GRANT UPDATE ON item TO players;

REVOKE ALL ON player FROM players;
REVOKE ALL ON player_inventory FROM players;
REVOKE ALL ON player_id_seq FROM players;
REVOKE ALL ON player_inventory_id_seq FROM players;
GRANT SELECT ON my_player TO players;
GRANT UPDATE ON my_player TO players;
GRANT SELECT ON my_player_inventory TO players;
GRANT SELECT ON online_players TO players;

REVOKE ALL ON ship_control FROM players;
REVOKE ALL ON ship_flight_recorder FROM players;
GRANT UPDATE ON my_ships TO players;
GRANT SELECT ON my_ships TO players;
GRANT INSERT ON my_ships TO players;
GRANT SELECT ON ships_in_range TO players;
GRANT SELECT ON my_ships_flight_recorder TO players;

REVOKE ALL ON ship FROM players;
REVOKE ALL ON ship_id_seq FROM players;


REVOKE ALL ON planet FROM players;
REVOKE ALL ON planet_id_seq FROM players;
REVOKE ALL ON planet_miners FROM players;
GRANT SELECT ON planets TO players;
GRANT UPDATE ON planets TO players;

REVOKE ALL ON event FROM players;
GRANT SELECT ON my_events TO players;

REVOKE ALL ON event_archive FROM players;
GRANT SELECT ON event_archive TO players;

REVOKE ALL ON trade FROM players;
REVOKE ALL ON trade_id_seq FROM players;
GRANT INSERT ON my_trades TO players;
GRANT SELECT ON my_trades TO players;
GRANT UPDATE ON my_trades TO players; 
GRANT DELETE ON my_trades TO players;

REVOKE ALL ON trade_item FROM players;
GRANT SELECT ON trade_items TO players;
GRANT SELECT ON trade_ship_stats TO players;
GRANT DELETE ON trade_items TO players;
GRANT INSERT ON trade_items TO players;

REVOKE ALL ON fleet FROM players;
REVOKE ALL ON fleet_id_seq FROM players;
GRANT INSERT ON my_fleets TO players;
GRANT SELECT ON my_fleets TO players;
GRANT UPDATE ON my_fleets TO players; 

REVOKE ALL ON price_list FROM players;
GRANT SELECT ON price_list TO players;

REVOKE ALL ON current_stats FROM players;
REVOKE ALL ON current_player_stats FROM players;
REVOKE ALL ON stat_log FROM players;
GRANT SELECT ON current_stats TO players;
GRANT SELECT ON current_player_stats TO players;
GRANT SELECT ON stat_log TO players;

REVOKE ALL ON action FROM players;
GRANT SELECT ON action TO players;
GRANT INSERT ON action TO players;
GRANT UPDATE ON action TO players;

REVOKE ALL ON trophy FROM players;
GRANT SELECT ON trophy TO players;
GRANT INSERT ON trophy TO players;
GRANT UPDATE ON trophy TO players;

REVOKE ALL ON player_trophy FROM players;
GRANT SELECT ON player_trophy TO players;

REVOKE ALL ON trophy_case FROM players;
GRANT SELECT ON trophy_case TO players;


CREATE OR REPLACE FUNCTION ROUND_CONTROL()
  RETURNS boolean AS
$round_control$
DECLARE
	new_planet record;
	trophies RECORD;
	p RECORD;
BEGIN

	IF NOT SESSION_USER = 'schemaverse' THEN
		RETURN 'f';
	END IF;	

	IF NOT GET_CHAR_VARIABLE('ROUND_START_DATE')::date <= 'today'::date - GET_CHAR_VARIABLE('ROUND_LENGTH')::interval THEN
		RETURN 'f';
	END IF;

	FOR trophies IN SELECT id FROM trophy WHERE approved='t' LOOP
		EXECUTE 'INSERT INTO player_trophy SELECT * FROM trophy_script_' || trophies.id ||'();';
	END LOOP;

	alter table planet disable trigger all;
	alter table fleet disable trigger all;
	alter table planet_miners disable trigger all;
	alter table trade_item disable trigger all;
	alter table trade disable trigger all;
	alter table ship_flight_recorder disable trigger all;
	alter table ship_control disable trigger all;
	alter table ship disable trigger all;
	alter table player_inventory disable trigger all;	
	alter table event disable trigger all;	

	--Deactive all fleets
        update fleet set runtime='0 minutes', enabled='f';

	--Delete only items that do not persist across rounds
        delete from player_inventory using item where item.system_name=player_inventory.item and item.persistent='f';

	--add archives of stats and events
	INSERT INTO event_archive SELECT (SELECT last_value FROM round_seq), event.* FROM event;

	--Delete everything else
        delete from planet_miners;
        delete from trade_item;
        delete from trade;
        delete from ship_flight_recorder;
        delete from ship_control;
        delete from ship;
        delete from event;
        delete from planet WHERE id != 1;

        alter sequence event_id_seq restart with 1;
        alter sequence ship_id_seq restart with 1;
        alter sequence tic_seq restart with 1;
        alter sequence trade_id_seq restart with 1;
        alter sequence trade_item_id_seq restart with 1;
	alter sequence planet_id_seq restart with 2;


	--Reset player resources
        UPDATE player set balance=10010000, fuel_reserve=100000 WHERE (starting_fleet=0 OR starting_fleet IS NULL) AND username!='schemaverse';

    	UPDATE player set balance=10000, fuel_reserve=100000 WHERE starting_fleet!=0 AND starting_fleet IS NOT NULL;
	UPDATE fleet SET runtime='1 minute', enabled='t' FROM player WHERE player.starting_fleet=fleet.id AND player.id=fleet.player_id;
 

	UPDATE planet SET fuel=20000000 WHERE id=1;

	WHILE (SELECT count(*) FROM planet) < (SELECT count(*) FROM player) * 1.05 LOOP
		FOR new_planet IN SELECT
			nextval('planet_id_seq') as id,
			CASE (RANDOM() * 11)::integer % 12
			WHEN 0 THEN 'Aethra_' || generate_series
                         WHEN 1 THEN 'Mony_' || generate_series
                         WHEN 2 THEN 'Semper_' || generate_series
                         WHEN 3 THEN 'Voit_' || generate_series
                         WHEN 4 THEN 'Lester_' || generate_series 
                         WHEN 5 THEN 'Rio_' || generate_series 
                         WHEN 6 THEN 'Zergon_' || generate_series 
                         WHEN 7 THEN 'Cannibalon_' || generate_series
                         WHEN 8 THEN 'Omicron Persei_' || generate_series
                         WHEN 9 THEN 'Urectum_' || generate_series
                         WHEN 10 THEN 'Wormulon_' || generate_series
                         WHEN 11 THEN 'Kepler_' || generate_series
			END as name,
                GREATEST((RANDOM() * 100)::integer, 30) as mine_limit,
                GREATEST((RANDOM() * 1000000000)::integer, 10000000) as fuel,
                GREATEST((RANDOM() * 10)::integer,2) as difficulty,
                CASE (RANDOM() * 1)::integer % 2
                        WHEN 0 THEN (RANDOM() * GET_NUMERIC_VARIABLE('UNIVERSE_CREATOR'))::integer 
                        WHEN 1 THEN (RANDOM() * GET_NUMERIC_VARIABLE('UNIVERSE_CREATOR') * -1)::integer
		END as location_x,
                CASE (RANDOM() * 1)::integer % 2
                        WHEN 0 THEN (RANDOM() * GET_NUMERIC_VARIABLE('UNIVERSE_CREATOR'))::integer
                        WHEN 1 THEN (RANDOM() * GET_NUMERIC_VARIABLE('UNIVERSE_CREATOR') * -1)::integer		
		END as location_y

		FROM generate_series(1,500)
		LOOP
			IF NOT ((SELECT COUNT(id) FROM planet WHERE location_x between new_planet.location_x-3000 and new_planet.location_x+3000
						AND location_y between new_planet.location_y-3000 and new_planet.location_y+3000) > 0) THEN
				INSERT INTO planet(id, name, mine_limit, difficulty, fuel, location_x, location_y)
					VALUES(new_planet.id, new_planet.name, new_planet.mine_limit, new_planet.difficulty, new_planet.fuel, new_planet.location_x, new_planet.location_y);
			END IF;	
		END LOOP;
	END LOOP;

	UPDATE planet SET conqueror_id=NULL WHERE planet.id = 1;
	FOR p IN SELECT player.id as id FROM player ORDER BY player.id LOOP
		UPDATE planet SET conqueror_id=p.id, mine_limit=30, fuel=50000000, difficulty=2 
			WHERE planet.id = (SELECT id FROM planet WHERE planet.id != 1 AND conqueror_id IS NULL ORDER BY RANDOM() LIMIT 1);
	END LOOP;

	alter table event enable trigger all;
	alter table planet enable trigger all;
	alter table fleet enable trigger all;
	alter table planet_miners enable trigger all;
	alter table trade_item enable trigger all;
	alter table trade enable trigger all;
	alter table ship_flight_recorder enable trigger all;
	alter table ship_control enable trigger all;
	alter table ship enable trigger all;
	alter table player_inventory enable trigger all;	

	PERFORM nextval('round_seq');

	UPDATE variable SET char_value='today'::date WHERE name='ROUND_START_DATE';

        RETURN 't';
END;
$round_control$
  LANGUAGE plpgsql;

-- These seem to make the largest improvement for performance
CREATE INDEX event_toc_index ON event USING btree (toc);
CREATE INDEX event_action_index ON event USING hash (action);
CREATE INDEX ship_location_index ON ship USING btree (location_x, location_y);
CREATE INDEX planet_location_index ON planet USING btree (location_x, location_y);
