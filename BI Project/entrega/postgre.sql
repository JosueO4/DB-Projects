-- =========================================================================
-- Punto 1: Hacer procedimientos, funciones, roles y usuarios.

-- -------------------------------------------------------------------------
-- Procedimientos y funciones

-- Procedimiento para registrar un alquiler

CREATE OR REPLACE PROCEDURE insertar_cliente(
    p_store_id smallint,
    p_first_name character varying,
    p_last_name character varying,
    p_email character varying,
    p_address_id smallint,
    p_activebool boolean,
    p_create_date date,
    p_last_update timestamp without time zone,
    p_active integer)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO customer (
        store_id,
        first_name,
        last_name,
        email,
        address_id,
        activebool,
        create_date,
        last_update,
        active
    ) VALUES (
        p_store_id,
        p_first_name,
        p_last_name,
        p_email,
        p_address_id,
        p_activebool,
        p_create_date,
        p_last_update,
        p_active
    );
END;
$$;

-- Procedimiento para registrar un alquiler

CREATE OR REPLACE PROCEDURE insertar_renta(
    p_rental_date timestamp without time zone,
    p_inventory_id integer,
    p_customer_id smallint,
    p_return_date timestamp without time zone,
    p_staff_id smallint,
    p_last_update timestamp without time zone
    )
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO rental (
        rental_date,
        inventory_id,
        customer_id,
        return_date,
        staff_id,
        last_update
    ) VALUES (
        p_rental_date,
        p_inventory_id,
        p_customer_id,
        p_return_date,
        p_staff_id,
        p_last_update
    );
END;
$$;

-- Procedimiento para registrar una devolución

CREATE OR REPLACE FUNCTION buscar_pelicula(p_film_id integer)
RETURNS SETOF film AS
$$
DECLARE
    resultado film;  -- Declarar una variable para almacenar el resultado
BEGIN
    -- Realizar la consulta y almacenar el resultado en la variable 'result'
    SELECT * INTO resultado FROM film WHERE film_id = p_film_id;
    
    -- Devolver el resultado
    RETURN NEXT resultado;
END;
$$
LANGUAGE plpgsql;

-- Procedimiento para registrar una devolución  

CREATE OR REPLACE PROCEDURE registrar_devolucion(
    p_customer_id smallint, -- id del cliente
    p_staff_id smallint, --id del staff
    p_rental_id integer, -- id de la renta
    p_payment_date timestamp without time zone -- es now
    )
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
    dias integer; -- dias totales
    fecha_renta timestamp without time zone; -- la fecha almacenada en la tabla rental
    p_amount numeric(5,2); -- cantidad a pagar
    p_rate numeric(4,2); -- el costo por dia
BEGIN

    select rental_date into fecha_renta from rental where rental_id = p_rental_id; -- asignamos la fecha renta

    dias := DATE_PART('day', p_payment_date - fecha_renta); -- calculamos los dias en integer

    select rental_rate into p_rate from film where film_id = (select film_id from inventory where inventory_id = (select inventory_id from rental where rental_id = p_rental_id)); -- asignamos el costo por dia
    p_amount := LEAST(dias * p_rate, 999.99); -- la cantidad a pagar se calcula paganado 0.99 por dia

-- se insertan los datos
    INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date) VALUES (
        p_customer_id,
        p_staff_id,
        p_rental_id,
        p_amount,
        p_payment_date
    );

END;
$$;

-- -------------------------------------------------------------------------
-- Roles

-- El rol de empleado
CREATE ROLE EMP;

GRANT EXECUTE ON PROCEDURE insertar_renta TO EMP;
GRANT EXECUTE ON PROCEDURE registrar_devolucion TO EMP;
GRANT EXECUTE ON FUNCTION buscar_pelicula(INTEGER) TO EMP;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM EMP;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM EMP;

-- El rol de administrador
CREATE ROLE ADMIN;

GRANT EXECUTE ON PROCEDURE insertar_cliente TO ADMIN;
GRANT EMP TO ADMIN;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM ADMIN;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM ADMIN;

-- -------------------------------------------------------------------------
-- Usuarios

-- El usuario video
CREATE USER video NOLOGIN;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO video;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO video;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO video;

-- El empleado 1
CREATE USER empleado1;
GRANT EMP TO empleado1;

-- El administrador 1
CREATE USER administrador1;
GRANT ADMIN TO administrador1;

-- -------------------------------------------------------------------------
-- Alterar procedimientos y funciones

ALTER PROCEDURE insertar_cliente OWNER TO video;
ALTER PROCEDURE registrar_devolucion OWNER TO video;
ALTER FUNCTION buscar_pelicula(integer) OWNER TO video;
ALTER PROCEDURE insertar_renta OWNER TO video;

-- -------------------------------------------------------------------------
-- Pruebas

call insertar_cliente(
    1 ::smallint, 
    'Pedro'::character varying,  
    'Ramirez' ::character varying,   
    'pedro@example.com' ::character varying, 
    1 ::smallint, 
    true, 
    '2023-10-16'::date,
    now() ::timestamp without time zone, 
    1  
);
call insertar_renta(
    '2023-10-16 14:30:00'::timestamp without time zone,
    1,  -- Reemplaza con el ID de inventario deseado
    1 ::smallint,  -- Reemplaza con el ID de cliente deseado
    '2023-10-18 14:30:00'::timestamp without time zone,  -- Fecha de retorno
    1 ::smallint,  -- Reemplaza con el ID de personal deseado
    '2023-10-16 14:30:00'::timestamp without time zone
);
select * from buscar_pelicula(4);
call registrar_devolucion(1 ::smallint, 1 ::smallint, 1, now() ::timestamp without time zone);

-- -------------------------------------------------------------------------
-- Eliminar procedimientos, funciones, usuarios y roles

DROP PROCEDURE insertar_cliente;
DROP PROCEDURE insertar_renta;
DROP PROCEDURE registrar_devolucion;

DROP FUNCTION buscar_pelicula(integer);

DROP USER empleado1;
DROP USER administrador1;

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM video;
REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public FROM video;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM video;
DROP USER video;

DROP ROLE EMP;
DROP ROLE ADMIN;

-- =========================================================================
-- Punto 2: Hacer la replicación de la base de datos.
-- Punto 3: Modelo multidimensional sobre la base de datos de ejemplo de PostgreSQL.

-- -------------------------------------------------------------------------
-- Las dimensiones

-- La dimensión de películas

CREATE TABLE dim_film (
    film_id integer NOT NULL,
    category_name character varying(25) NOT NULL,
    actor_name character varying(90) NOT NULL,
    actor_first_name character varying(45) NOT NULL,
    actor_last_name character varying(45) NOT NULL
);

-- La dimensión de direcciones

CREATE TABLE dim_address (
    address_id integer NOT NULL,
    country character varying(50) NOT NULL,
    city character varying(50) NOT NULL
);

-- La dimensión de alquileres

CREATE TABLE dim_rental (
    rental_id integer NOT NULL,
    date timestamp without time zone NOT NULL,
    year integer NOT NULL,
    month integer NOT NULL,
    day integer NOT NULL
);

-- La dimensión de sucursales

CREATE TABLE dim_store (
    store_id integer NOT NULL
);

-- -------------------------------------------------------------------------
-- Las tabla de hechos

-- El hecho de alquileres

CREATE TABLE hechos_alquileres (
    film_id integer NOT NULL,
    address_id integer NOT NULL,
    rental_id integer NOT NULL,
    store_id integer NOT NULL,
    total_alquileres integer NOT NULL,
    monto_total numeric(5,2) NOT NULL
);

-- -------------------------------------------------------------------------
-- Procedimientos para poblar las dimensiones

-- Procedimiento para poblar la tabla de hechos

CREATE OR REPLACE PROCEDURE poblar_dim_film() AS $$
DECLARE
    film_id integer;
    category_name character varying(25);
    actor_first_name character varying(45);
    actor_last_name character varying(45);
BEGIN
    FOR film_id, category_name, actor_first_name, actor_last_name IN
        SELECT film.film_id, category.name, actor.first_name, actor.last_name
        FROM film
        INNER JOIN film_category ON film.film_id = film_category.film_id
        INNER JOIN category ON film_category.category_id = category.category_id
        INNER JOIN film_actor ON film.film_id = film_actor.film_id
        INNER JOIN actor ON film_actor.actor_id = actor.actor_id
    LOOP
        INSERT INTO dim_film VALUES (film_id, category_name, actor_first_name || ' ' || actor_last_name, actor_first_name, actor_last_name);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Procedimiento para poblar la tabla de hechos

CREATE OR REPLACE PROCEDURE poblar_dim_address() AS $$
DECLARE
    address_id integer;
    country character varying(50);
    city character varying(50);
BEGIN
    FOR address_id, country, city IN
        SELECT address.address_id, country.country, city.city
        FROM address
        INNER JOIN city ON address.city_id = city.city_id
        INNER JOIN country ON city.country_id = country.country_id
    LOOP
        INSERT INTO dim_address VALUES (address_id, country, city);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Procedimiento para poblar la tabla de hechos

CREATE OR REPLACE PROCEDURE poblar_dim_rental() AS $$
DECLARE
    rental_id integer;
    date timestamp without time zone;
    year integer;
    month integer;
    day integer;
BEGIN
    FOR rental_id, date, year, month, day IN
        SELECT rental.rental_id, rental.rental_date, EXTRACT(YEAR FROM rental.rental_date), EXTRACT(MONTH FROM rental.rental_date), EXTRACT(DAY FROM rental.rental_date)
        FROM rental
    LOOP
        INSERT INTO dim_rental VALUES (rental_id, date, year, month, day);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Procedimiento para poblar la tabla de hechos

CREATE OR REPLACE PROCEDURE poblar_dim_store() AS $$
DECLARE
    store_id integer;
BEGIN
    FOR store_id IN
        SELECT store.store_id
        FROM store
    LOOP
        INSERT INTO dim_store VALUES (store_id);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- -------------------------------------------------------------------------
-- Procedimientos para poblar las tablas de hechos

-- Procedimiento para poblar la tabla de hechos de los alquileres

CREATE OR REPLACE PROCEDURE poblar_hechos_alquileres() AS $$
DECLARE
    film_id integer;
    address_id integer;
    rental_id integer;
    store_id integer;
    total_alquileres integer;
    monto_total numeric(5,2);
BEGIN
    FOR film_id, address_id, rental_id, store_id, total_alquileres, monto_total IN
        SELECT inventory.film_id, customer.address_id, rental.rental_id, inventory.store_id, COUNT(rental.rental_id), SUM(payment.amount)
        FROM rental
        INNER JOIN inventory ON rental.inventory_id = inventory.inventory_id
        INNER JOIN payment ON rental.rental_id = payment.rental_id
        INNER JOIN customer ON rental.customer_id = customer.customer_id
		GROUP BY inventory.film_id, customer.address_id, rental.rental_id, inventory.store_id
    LOOP
        INSERT INTO hechos_alquileres VALUES (film_id, address_id, rental_id, store_id, total_alquileres, monto_total);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- -------------------------------------------------------------------------
-- Truncate de tablas para el servidor 2

DO $$ DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = current_schema()) LOOP
        EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.tablename) || ' CASCADE';
    END LOOP;
END $$;

-- -------------------------------------------------------------------------
-- Pruebas

CALL poblar_dim_film();
CALL poblar_dim_address();
CALL poblar_dim_rental();
CALL poblar_dim_store();
CALL poblar_hechos_alquileres();

-- -------------------------------------------------------------------------
-- Eliminar tablas y procedimientos

DROP PROCEDURE poblar_dim_film();
DROP PROCEDURE poblar_dim_address();
DROP PROCEDURE poblar_dim_rental();
DROP PROCEDURE poblar_dim_store();
DROP PROCEDURE poblar_hechos_alquileres();

DROP TABLE dim_film;
DROP TABLE dim_address;
DROP TABLE dim_rental;
DROP TABLE dim_store;
DROP TABLE hechos_alquileres;