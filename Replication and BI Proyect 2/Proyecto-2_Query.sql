-------------------------------------------------------------------------------
-------- FUNCIONES Y PROCEDIMIENTOS - MODELOS TRANSACCIONAL, TABLAS OG --------
-------------------------------------------------------------------------------

/*----------------------------------------------------------
* [Función]: get_film.
* [Descripción]: se encarga de buscar una pelicula en la 
* | base de datos que corresponda con un "titulo" ingresado.
* [Bloques relevantes]: tabla "film".
* 
* @param {TEXT} p_titulo:  Titulo de la película a buscar.
* 
* @returns {SETOF film}: todas las filas de la tabla "film"
* | dónde el input coincida con la columna de "title".
-----------------------------------------------------------*/
CREATE OR REPLACE FUNCTION get_film(p_titulo text DEFAULT NULL)
RETURNS SETOF film AS $$
BEGIN
        RETURN QUERY
        SELECT *
        FROM film
        WHERE title = p_titulo;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--Asignación de creedenciales.
ALTER FUNCTION get_film(p_titulo text)       
OWNER TO video;
-- Fin función: get_film.
--SELECT * FROM get_film ('Airport Pollock');
--SELECT * FROM film;


/*----------------------------------------------------------------------------------------------
* [Proceso]: insert_customer.
* [Descripción]: inserta un nuevo cliente en la tabla "customer"
* [Bloques relevantes]: tabla "customer", tabla "address", tabla "store".
* 
* @param {INTEGER} p_store_id:      (llave fóranea) id de la tienda donde se registra el cliente.
* @param {VARCHAR} p_first_name:    nombre del cliente.
* @param {VARCHAR} p_last_name:     apellido del cliente.
* @param {VARCHAR} p_email:         correo electrónico del cliente, acepta nulos.
* @param {INTEGER} p_address_id:    (llave fóranea) id de la dirreción del cliente.
* @param {BOOLEAN} p_active:        indica si un cliente está activo, acepta nulos.
* @param {TIMESTAMP} p_create_date: fecha en la que se registra el cliente.
* @param {INT} p_active_int:        ???????????, acepta nulos.
* 
* @returns {INTEGER} customer_id: NO RETORNA NINGÚN VALOR. Inserta una nuevo cliente en la tabla
* | "customer", por lo que crea un nuevo id en esta.
-----------------------------------------------------------------------------------------------*/
CREATE OR REPLACE PROCEDURE insert_customer(
	--Definición: Varibables del proceso.
    p_store_id INTEGER,
    p_first_name VARCHAR,
    p_last_name VARCHAR,
    p_email VARCHAR,
    p_address_id INTEGER,
    p_active BOOLEAN,
    p_create_date TIMESTAMP,
	p_active_int INT
)
AS $$
BEGIN
    -- Se insertan los valores ingresados en la table clientes.
    INSERT INTO customer (store_id, first_name, last_name, email, address_id, activebool, create_date, active)
    VALUES (p_store_id, p_first_name, p_last_name, p_email, p_address_id, p_active, p_create_date, p_active_int);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--Asignación de creedenciales.
ALTER PROCEDURE insert_customer(p_store_id INTEGER, p_first_name VARCHAR, p_last_name VARCHAR,
    						    p_email VARCHAR, p_address_id INTEGER, p_active BOOLEAN,
							    p_create_date TIMESTAMP, p_active_int INT)
OWNER TO video;
--Fin proceso: insert_customer.
--SELECT * FROM customer;
--SELECT * FROM address;
--CALL insert_customer(1, 'Julian', 'Navarrosa', '', 1, TRUE, '2023-10-10', 1)


/*--------------------------------------------------------------------------------------
* [Proceso]: registrar_devolucion.
* [Descripción]: agrega un registro a la tabla "payment".
* | Calcula el monto a pagar de una devolución en base a la
* | cantidad que duro el alquiler.
* [Bloques relevantes]: tabla "payment".
* 
* @param {SMALLINT} p_customer_id: id del cliente que hace la devolución.
* @param {SMALLINT} p_staff_id:    id del empleado que registra la devolución.
* @param {INTEGER} p_rental_id:    id del alquiler al que está asociado el alquiler.
* @param {TIMESTAMP WITHOUT TIME ZONE} p_payment_date: fecha en la que se hace el pago.
*
* @var {NUMERIC} v_amount: variable definida en el procedure. Guarda el cálculo del monto.
* 
* @returns {INTEGER} payment_id:  NO RETORNA NINGÚN VALOR. Inserta una nuevo cliente en
* | la tabla "payment", por lo que crea un nuevo id en esta.
---------------------------------------------------------------------------------------*/ 
CREATE OR REPLACE PROCEDURE register_devolution(
    p_customer_id SMALLINT,			
    p_staff_id SMALLINT,				
    p_rental_id INTEGER,				
	p_payment_date TIMESTAMP WITHOUT TIME ZONE		
)
AS $$
DECLARE
    v_amount numeric;							
BEGIN
    -- Cálculo del monto
	SELECT EXTRACT(EPOCH FROM (p_payment_date - r.rental_date)) / 3600 / 24 * f.rental_rate INTO v_amount
	FROM rental r
	JOIN inventory i ON r.inventory_id = i.inventory_id
	JOIN film f ON i.film_id = f.film_id
	WHERE r.rental_id = p_rental_id;
	
	-- Excepción por si no se puede calcular el monto.
	IF v_amount IS NULL THEN
        RAISE EXCEPTION 'No se pudo calcular el monto a pagar';
    END IF;
	
	-- Inserta la devolución en la tabla payment
    INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date)
    VALUES (p_customer_id, p_staff_id, p_rental_id, v_amount, p_payment_date);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--Asignación de creedenciales.
ALTER PROCEDURE register_devolution(p_customer_id SMALLINT, p_staff_id SMALLINT, p_rental_id INTEGER, p_payment_date TIMESTAMP WITHOUT TIME ZONE		
)
OWNER TO video;

--Fin proceso: registrar_devolucion
--call register_devolution(341::smallint, 2::smallint, 1778::integer, '2005-06-20 15:13:00'::timestamp);
--select * from payment where customer_id = 341 and staff_id = 2 and rental_id = 1778;


/*-------------------------------------------------------------------------------------------------------------
* [Proceso]: registerRental.
* [Descripción]: ingresa un nuevo alquiler a la tabla de rentals. 
* |
* [Bloques relevantes]: tabla "rental".
* 
* @param {INTEGER} p_inventory_id: (llave foranea) id del inventario asociado al alquiler.
* @param {SMALLINT} p_customer_id: (llave foranea) id del cliente que solictó el alquiler.
* @param {SMALLINT} p_staff_id:   (llave foranea) id del empleado que autorizó el alquiler.
* @param {TIMESTAMP WITHOUT TIME ZONE} p_rental_date: fecha y hora en la que se registró el alquiler.
* @param {TIMESTAMP WITHOUT TIME ZONE} p_return_date: fecha y hora en la que se hace la devolución del alquiler.
* 
* @returns {INTEGER} rental_id: NO RETORNA NINGÚN VALOR. Inserta una nuevo alquiler en la tabla
* | "rental", por lo que crea un nuevo id en esta.
-------------------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE PROCEDURE registerRental (
	--Definición: Varibables del proceso.
	p_rental_date TIMESTAMP WITHOUT TIME ZONE,
  	p_inventory_id INTEGER,
 	p_customer_id SMALLINT,
 	p_return_date TIMESTAMP WITHOUT TIME ZONE,
	p_staff_id SMALLINT
)
AS $$
BEGIN
	-- Se hace el insert de los valores ingresados a la tabla de rentals.
	INSERT INTO rental (rental_id, rental_date, inventory_id, customer_id, return_date, staff_id)
	VALUES(nextval('rental_rental_id_seq'), p_rental_date, p_inventory_id, p_customer_id, p_return_date, p_staff_id);
	COMMIT;
END;
$$ LANGUAGE plpgsql;

--Asignación de creedenciales.
ALTER PROCEDURE registerRental(	p_rental_date TIMESTAMP WITHOUT TIME ZONE, p_inventory_id INTEGER,
 								p_customer_id SMALLINT, p_return_date TIMESTAMP WITHOUT TIME ZONE,
								p_staff_id SMALLINT)
OWNER TO video;
--Fin proceso: registerRental.
--CALL registerRental ('2010-01-01 15:30:30'::timestamp, 1525::integer, 408::smallint, '2010-01-06 15:00:00'::timestamp, 2::smallint);
--SELECT * FROM rental where rental_date = '2010-01-01 15:30:30';

---------------------------------------------------------------------------------
-------- CREACIÓN DE ROLES Y USUARIOS - ASIGNACIÓN DE PERMISOS Y REVOKES --------
---------------------------------------------------------------------------------

/*Crea un rol temporal para asignar ownership
* en caso de que se necesite dropear un role.
*/
CREATE ROLE temp_elim;

/*Se trasfiere el ownership de EMP a temp_elim
* Se elimian los objetos de EMP y después el 
* rol en sí
*/
REASSIGN OWNED BY EMP TO temp_elim;
DROP OWNED BY EMP;
DROP ROLE EMP;

/*Se trasfiere el ownership de empleado1 
* a temp_elim. Se elimian los objetos de  
* empleado1 y después el rol en sí.
*/
REASSIGN OWNED BY empleado1 TO temp_elim;
DROP OWNED BY empleado1;
DROP ROLE empleado1;

/*Se trasfiere el ownership de ADMIN a
* temp_elim. Se elimian los objetos de  
* ADMIN y después el rol en sí.
*/
REASSIGN OWNED BY ADMIN TO temp_elim;
DROP OWNED BY ADMIN;
DROP ROLE ADMIN;

/*Se trasfiere el ownership de administrador1
* a temp_elim. Se elimian los objetos de  
* administrador1 y después el rol en sí.
*/
REASSIGN OWNED BY administrador1 TO temp_elim;
DROP OWNED BY administrador1;
DROP ROLE administrador1;

/*Se trasfiere el ownership de video a
* temp_elim. Se elimian los objetos de  
* video y después el rol en sí.
*/
REASSIGN OWNED BY video TO temp_elim;
DROP OWNED BY video;
DROP ROLE video;

/*Se trasfiere el ownership de temp_elim
* a postgres. Se elimian los objetos de  
* temp_elim y después el rol en sí.
*/
REASSIGN OWNED BY temp_elim TO postgres;
DROP OWNED BY temp_elim;
DROP ROLE temp_elim;

/*Linea para ver los roles de la BD*/
-- SELECT rolname FROM pg_roles;

/*Lineas para probar funcionalidad de los roles y users*/
--select * from actor;
--select * from get_film('Airport Pollock');
--call insert_customer(1, 'Juliadfgfaan', 'Navaasdgrrosa', 'nasgs@gmail.com', 1, TRUE, '2023-10-10', 1);

--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------

/*Creal el role EMP*/
create role EMP;

/*Asigna los permisos para el rol EMP sobre la función get_fim*/
grant execute on function get_film(p_titulo text) to EMP;

/*Asigna los permisos para el rol EMP sobre la procedure registerRental*/
grant execute on procedure registerRental (
	p_rental_date TIMESTAMP WITHOUT TIME ZONE, p_inventory_id INTEGER,
 	p_customer_id SMALLINT, p_return_date TIMESTAMP WITHOUT TIME ZONE,
	p_staff_id SMALLINT
	) to EMP;
	
/*Asigna los permisos para el rol EMP sobre la procedure registrar_devolucion*/
grant execute on procedure registrar_devolucion(p_rental_id INT) to EMP;

/*Le quita los permisos de ejecutar el procedure insert_customer a EMP*/
REVOKE EXECUTE ON PROCEDURE insert_customer(
    p_store_id INTEGER,
    p_first_name VARCHAR,
    p_last_name VARCHAR,
    p_email VARCHAR,
    p_address_id INTEGER,
    p_active BOOLEAN,
    p_create_date TIMESTAMP,
    p_active_int INT) 
FROM EMP;

/*Remueve la posibilidad ejecutar el procedure insert_customer desde el esquema public*/
REVOKE EXECUTE ON PROCEDURE insert_customer(
    p_store_id INTEGER,
    p_first_name VARCHAR,
    p_last_name VARCHAR,
    p_email VARCHAR,
    p_address_id INTEGER,
    p_active BOOLEAN,
    p_create_date TIMESTAMP,
    p_active_int INT)
FROM public;

--------------------------------------------------------------------------------------------------------

/*Crea el rol ADMIN*/
create role ADMIN; 

/*Asigna todos los permisos de EMP a ADMIN*/
grant EMP to ADMIN;

/*Permite ejecutar el procedure insert_customer desde ADMIN*/
grant execute on procedure insert_customer(
    p_store_id INTEGER,
    p_first_name VARCHAR,
    p_last_name VARCHAR,
    p_email VARCHAR,
    p_address_id INTEGER,
    p_active BOOLEAN,
    p_create_date TIMESTAMP,
	p_active_int INT
) to ADMIN;


/*Crea el user video, sin capacidad de logearse en la DB*/
create user video nologin;

/*Le asigna el status de SUPERUSER a video*/
alter user video with superuser;

/*Se le conceden todos los permisos sobre la base de datos a video*/
grant all privileges on all tables in schema public to video;
grant all privileges on database dvdrental to video;

/*Se crea un usuario EMP con contraseña*/
create user empleado1 with password '123';
grant EMP to empleado1;

/*Se crea un usuario ADMIN con contraseña*/
create user administrador1 with password '123';
grant ADMIN to administrador1; 



--------------------------------------------------------------------------
-------- MODELO MULTIDIMENSIONAL - DIMENACIONES Y TABLA DE HECHOS --------
--------------------------------------------------------------------------

-- se eliminan las tablas de las dimensiones y la tabla de hechos
drop table dimension_film cascade;
drop table dimension_address cascade;
drop table dimension_rental cascade;
drop table dimension_store cascade;
drop table dimension_actor cascade;
drop table dimension_film_actor cascade;
drop table tabla_hechos cascade;

-- tabla de dimension film
create table dimension_film(
 id_film integer primary key,
 title character varying,
 movie_category character varying
);

-- tabla de dimension address (ciudad)
create table dimension_address(
 city_id integer primary key,
 country_name character varying,
 city_name character varying
);

-- tabla de dimension actor
create table dimension_actor(
  id_actor integer primary key,
  actor_first_name character varying,
  actor_last_name character varying
)

-- tabla de dimension film en relacion con actor (para poder hacer la relacion de muchos a muchos)
CREATE TABLE dimension_film_actor (
    id_film_actor serial PRIMARY KEY,
    id_film integer,
    id_actor integer,
    foreign key (id_film) references dimension_film(id_film),
    foreign key (id_actor) references dimension_actor(id_actor)
);

-- table de dimension rental
create table dimension_rental(
 rental_id integer primary key,
 rental_date timestamp without time zone
);

-- tabla de dimension store
create table dimension_store(
 store_id integer primary key
);

-- tabla de hechos
create table tabla_hechos(
    -- llaves foraneas
    id_film integer,
    city_id integer,
    rental_id integer,
    store_id integer,
    -- medidas de interes
    num_alquileres integer,
    monto_total_cobrado_por_alquileres numeric,
    -- referencias a sus respectivas dimensiones
    foreign key (id_film) references dimension_film(id_film),
    foreign key (city_id) references dimension_address(city_id),
    foreign key (rental_id) references dimension_rental(rental_id),
    foreign key (store_id) references dimension_store(store_id)
);

-- Procedimientos almacenados para alimentar las tablas de dimension y la tabla de hechos

/* Procedimiento para alimentar la tabla de dimension film
 * Descripcion: Este procedimiento se encarga de alimentar la tabla de dimension film
 * Parametros: No recibe parametros
 * Salida: Actualiza la tabla de dimension film con los datos de la tabla film de interes para el modelo estrella
 */
CREATE OR REPLACE PROCEDURE alimentar_dimension_film() 
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO dimension_film (id_film, title, movie_category)
    -- id de la pelicula, titulo de la pelicula, categoria de la pelicula
    SELECT film.film_id, film.title, category.name
    FROM category
    -- se hace un join con la tabla film_category para obtener el id de la categoria de la pelicula
    INNER JOIN film_category ON category.category_id = film_category.category_id
    -- se hace un join con la tabla film para obtener el id de la pelicula y el titulo de la pelicula
    INNER JOIN film ON film_category.film_id = film.film_id;
END;
$$;

/* Procedimiento para alimentar la tabla de dimension actor
 * Descripcion: Este procedimiento se encarga de alimentar la tabla de dimension actor
 * Parametros: No recibe parametros
 * Salida: Actualiza la tabla de dimension actor con los datos de la tabla actor de interes para el modelo estrella
 */
CREATE OR REPLACE PROCEDURE alimentar_dimension_actor()
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO dimension_actor (id_actor, actor_first_name, actor_last_name)
    -- id del actor, nombre del actor, apellido del actor
    SELECT actor_id, first_name, last_name
    FROM actor;
END;
$$;

/* Procedimiento para alimentar la tabla de dimension film_actor
 * Descripcion: Este procedimiento se encarga de alimentar la tabla de dimension film_actor (relacion entre film y actor)
 *              El objetivo de esta tabla es poder hacer la relacion de muchos a muchos entre las tablas de dimension film y actor.
 * Parametros: No recibe parametros
 * Salida: Actualiza la tabla de dimension film_actor con los datos de la tabla film_actor de interes para el modelo estrella
 */
CREATE OR REPLACE PROCEDURE alimentar_dimension_film_actor()
LANGUAGE plpgsql AS $$
BEGIN
    -- Insertar datos en dimension_film_actor desde la tabla film_actor
    INSERT INTO dimension_film_actor (id_film, id_actor)
    SELECT film_id, actor_id
    FROM film_actor;
END;
$$;

/* Procedimiento para alimentar la tabla de dimension address (direcccion)
 * Descripcion: Este procedimiento se encarga de alimentar la tabla de dimension address
 * Parametros: No recibe parametros
 * Salida: Actualiza la tabla de dimension address con los datos de la tabla address de interes para el modelo estrella
*/
CREATE OR REPLACE PROCEDURE alimentar_dimension_address() 
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO dimension_address (city_id, country_name, city_name)
    SELECT DISTINCT ON (city.city_id) 
           city.city_id, country.country, city.city
    FROM address
    INNER JOIN city ON address.city_id = city.city_id
    INNER JOIN country ON city.country_id = country.country_id;
END;
$$;

/* Procedimiento para alimentar la tabla de dimension rental
 * Descripcion: Este procedimiento se encarga de alimentar la tabla de dimension rental
 * Parametros: No recibe parametros
 * Salida: Actualiza la tabla de dimension rental con los datos de la tabla rental de interes para el modelo estrella
*/
CREATE OR REPLACE PROCEDURE alimentar_dimension_rental()
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO dimension_rental (rental_id, rental_date)
    SELECT rental.rental_id, rental.rental_date
    FROM rental;
END;
$$;

/* Procedimiento para alimentar la tabla de dimension store
 * Descripcion: Este procedimiento se encarga de alimentar la tabla de dimension store
 * Parametros: No recibe parametros
 * Salida: Actualiza la tabla de dimension store con los datos de la tabla store de interes para el modelo estrella
 */
CREATE OR REPLACE PROCEDURE alimentar_dimension_store ()
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO dimension_store (store_id)
    SELECT store_id
    FROM store;
END;
$$;

/* Procedimiento para alimentar la tabla de hechos
 * Descripcion Inserta los datos en la tabla de hechos con los datos de las tablas de dimension y la tablas de dvd rental
 * Parametros: No recibe parametros
 * Salida: Actualiza la tabla de hechos
*/
CREATE OR REPLACE PROCEDURE alimentar_tabla_hechos()
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO tabla_hechos (id_film, city_id, rental_id, store_id, num_alquileres, monto_total_cobrado_por_alquileres)
    SELECT dimension_film.id_film, city.city_id, dimension_rental.rental_id, store.store_id, COUNT(rental.rental_id), SUM(payment.amount)
    FROM dimension_film
    INNER JOIN film ON dimension_film.id_film = film.film_id
    INNER JOIN inventory ON inventory.film_id = film.film_id
    INNER JOIN store ON store.store_id = inventory.store_id
    INNER JOIN rental ON rental.inventory_id = inventory.inventory_id
    INNER JOIN dimension_rental ON dimension_rental.rental_id = rental.rental_id
    INNER JOIN address ON store.address_id = address.address_id
    INNER JOIN city ON city.city_id = address.city_id
    INNER JOIN payment ON payment.rental_id = dimension_rental.rental_id
    GROUP BY dimension_film.id_film, city.city_id, dimension_rental.rental_id, store.store_id;
END;
$$;

CALL alimentar_dimension_film();
CALL alimentar_dimension_actor();
CALL alimentar_dimension_film_actor();
CALL alimentar_dimension_address();
CALL alimentar_dimension_rental();
CALL alimentar_dimension_store();
CALL alimentar_tabla_hechos();

-- Tabla de dimensiones dimension_film
SELECT * FROM dimension_film;
-- Tabla de dimensiones dimension_address
SELECT * FROM dimension_address;
-- Tabla de dimensiones dimension_actor
SELECT * FROM dimension_actor;
-- Tabla de relación dimension_film_actor
SELECT * FROM dimension_film_actor;
-- Tabla de dimensiones dimension_rental
SELECT * FROM dimension_rental;
-- Tabla de dimensiones dimension_store
SELECT * FROM dimension_store;
-- Tabla de hechos
SELECT * FROM tabla_hechos;