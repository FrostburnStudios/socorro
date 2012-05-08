\set ON_ERROR_STOP 1

CREATE OR REPLACE FUNCTION add_new_release (
	product citext,
	version citext,
	release_channel citext,
	build_id numeric,
	platform citext,
	beta_number integer default NULL,
	repository text default 'release',
	update_products boolean default false
)
RETURNS boolean
LANGUAGE plpgsql 
AS $f$
-- adds a new release to the releases_raw table
-- to be picked up by update_products later
-- does some light format validation

-- check for NULLs, blanks
IF NOT ( nonzero_string(product) AND nonzero_string(version)
	nonzero_string(release_channel) and nonzero_string(platform)
	AND build_id IS NOT NULL ) THEN
	RAISE EXCEPTION 'product, version, release_channel, platform and build ID are all required');
END IF;

--validations
-- validate product
SELECT validate_lookup('products','product_name',product,'product');
--validate channel
SELECT validate_lookup('release_channels','release_channel',release_channel,'release channel');
--validate build
IF NOT ( build_date(build_id) BETWEEN '2005-01-01' 
	AND (current_date + '1 month') ) THEN
	RAISE EXCEPTION 'invalid buildid';
END IF;

--add row
--duplicate check will occur in the EXECEPTION section
INSERT INTO releases_raw (
	product_name, version, platform, build_id,
	build_type, beta_number, repository )
VALUES ( product, version, platform, build_id, 
	release_channel, beta_number, repository );

--call update_products, if desired
IF update_products THEN
	SELECT update_product_versions();
END IF;

--return
RETURN TRUE;

--exception clause, mainly catches duplicate rows.
EXCEPTION
	WHEN UNIQUE_VIOLATION THEN
		RAISE EXCEPTION 'the release you have entered is already present in he database';
END;$f$;







