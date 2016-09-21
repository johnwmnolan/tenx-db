CREATE OR REPLACE PACKAGE BODY mongo_load_pkg
IS
   address_separator   VARCHAR2( 2 ) := ', ';

   FUNCTION coalesce_address( in_address_1    administrator_dump.address_1%TYPE
                            , in_address_2    administrator_dump.address_2%TYPE
                            , in_address_3    administrator_dump.address_3%TYPE
                            , in_address_4    administrator_dump.address_4%TYPE
                            , in_address_5    administrator_dump.address_5%TYPE )
      RETURN VARCHAR2
   IS
      out_address   VARCHAR2( 4000 );
   BEGIN
      SELECT    in_address_1
             || NVL2( in_address_2, address_separator || in_address_2, NULL )
             || NVL2( in_address_3, address_separator || in_address_3, NULL )
             || NVL2( in_address_4, address_separator || in_address_4, NULL )
             || NVL2( in_address_5, address_separator || in_address_5, NULL )
        INTO out_address
        FROM DUAL;

      RETURN out_address;
   END coalesce_address;

   PROCEDURE generate_json
   IS
      person     json;
      policy     json;
      policies   json_list;
      ret_val    json_list;

      CURSOR cur_key_fields
      IS
         SELECT forename
              , surname
              , dob
              , address_1
           FROM administrator_dump
         UNION
         SELECT forename
              , surname
              , dob
              , address_1
           FROM cloas_dump
         UNION
         SELECT forename
              , surname
              , dob
              , address_1
           FROM health_dump;

      CURSOR cur_person( p_forename     administrator_dump.forename%TYPE
                       , p_surname      administrator_dump.surname%TYPE
                       , p_dob          administrator_dump.dob%TYPE
                       , p_address_1    administrator_dump.address_1%TYPE )
      IS
         SELECT *
           FROM (SELECT title
                      , forename
                      , surname
                      , ppsn
                      , dob
                      , gender
                      , mstat
                      , address_1
                      , address_2
                      , address_3
                      , address_4
                      , address_5
                   FROM administrator_dump
                 UNION ALL
                 SELECT title
                      , forename
                      , surname
                      , NULL
                      , dob
                      , gender
                      , marital_status
                      , address_1
                      , address_2
                      , address_3
                      , NULL
                      , NULL
                   FROM cloas_dump
                 UNION ALL
                 SELECT title
                      , forename
                      , surname
                      , ppsn
                      , dob
                      , gender
                      , mstat
                      , address_1
                      , address_2
                      , address_3
                      , address_4
                      , address_5
                   FROM health_dump) p
          WHERE forename = p_forename
            AND surname = p_surname
            AND dob = p_dob
            AND address_1 = p_address_1
            AND ROWNUM = 1;

      CURSOR cur_admin_policy( p_forename     administrator_dump.forename%TYPE
                             , p_surname      administrator_dump.surname%TYPE
                             , p_dob          administrator_dump.dob%TYPE
                             , p_address_1    administrator_dump.address_1%TYPE )
      IS
         SELECT refno
              , status
              , retire_dt
              , scheme_no
              , scheme_nm
           FROM administrator_dump a
          WHERE a.forename = p_forename
            AND a.surname = p_surname
            AND a.dob = p_dob
            AND a.address_1 = p_address_1;

      CURSOR cur_cloas_policy( p_forename     administrator_dump.forename%TYPE
                             , p_surname      administrator_dump.surname%TYPE
                             , p_dob          administrator_dump.dob%TYPE
                             , p_address_1    administrator_dump.address_1%TYPE )
      IS
         SELECT policy_no
              , policy_status
              , retirement_dt
              , scheme_no
              , scheme_nm
           FROM cloas_dump a
          WHERE a.forename = p_forename
            AND a.surname = p_surname
            AND a.dob = p_dob
            AND a.address_1 = p_address_1;

      CURSOR cur_health_policy( p_forename     administrator_dump.forename%TYPE
                             , p_surname      administrator_dump.surname%TYPE
                             , p_dob          administrator_dump.dob%TYPE
                             , p_address_1    administrator_dump.address_1%TYPE )
      IS
         SELECT policy_no
              , plan_type
              , start_dt
              , renewal_dt
           FROM health_dump a
          WHERE a.forename = p_forename
            AND a.surname = p_surname
            AND a.dob = p_dob
            AND a.address_1 = p_address_1;
   BEGIN
      ret_val := json_list( );

      FOR rec IN cur_key_fields
      LOOP
         person := json( );

         FOR per_rec IN cur_person( rec.forename
                                  , rec.surname
                                  , rec.dob
                                  , rec.address_1 )
         LOOP
            person.put( 'title'
                      , per_rec.title );
            person.put( 'forename'
                      , per_rec.forename );
            person.put( 'surname'
                      , per_rec.surname );
            person.put( 'ppsn'
                      , per_rec.ppsn );
            person.put( 'dob'
                      , json_ext.to_json_value( per_rec.dob ) );
            person.put( 'gender'
                      , per_rec.gender );
            person.put( 'maritalStatus'
                      , per_rec.mstat );
            person.put( 'address'
                      , coalesce_address( per_rec.address_1
                                        , per_rec.address_2
                                        , per_rec.address_3
                                        , per_rec.address_4
                                        , per_rec.address_5 ) );

            --Add policies
            policies := json_list( );

            FOR admin_rec IN cur_admin_policy( per_rec.forename
                                             , per_rec.surname
                                             , per_rec.dob
                                             , per_rec.address_1 )
            LOOP
               policy := json( );

               policy.put( 'lob'
                         , 'CB' );
               policy.put( 'policyID'
                         , admin_rec.refno );
               policy.put( 'retireDate'
                         , json_ext.to_json_value( admin_rec.retire_dt ) );
               policy.put( 'schemeNo'
                         , admin_rec.scheme_no );
               policy.put( 'schemeName'
                         , admin_rec.scheme_nm );
               policy.put( 'policyStatus'
                         , admin_rec.status );

               policies.append( policy.to_json_value );
            END LOOP;

            FOR cloas_rec IN cur_cloas_policy( per_rec.forename
                                             , per_rec.surname
                                             , per_rec.dob
                                             , per_rec.address_1 )
            LOOP
               policy := json( );

               policy.put( 'lob'
                         , 'Retail' );
               policy.put( 'policyID'
                         , cloas_rec.policy_no );
               policy.put( 'retireDate'
                         , json_ext.to_json_value( cloas_rec.retirement_dt ) );
               policy.put( 'schemeNo'
                         , cloas_rec.scheme_no );
               policy.put( 'schemeName'
                         , cloas_rec.scheme_nm );
               policy.put( 'policyStatus'
                         , cloas_rec.policy_status );

               policies.append( policy.to_json_value );
            END LOOP;

            FOR health_rec IN cur_health_policy( per_rec.forename
                                             , per_rec.surname
                                             , per_rec.dob
                                             , per_rec.address_1 )
            LOOP
               policy := json( );

               policy.put( 'lob'
                         , 'Health' );
               policy.put( 'policyID'
                         , health_rec.policy_no );
               policy.put( 'planType'
                         , health_rec.plan_type );
               policy.put( 'startDate'
                         , json_ext.to_json_value( health_rec.start_dt ) );
               policy.put( 'renewalDate'
                         , json_ext.to_json_value( health_rec.renewal_dt ) );

               policies.append( policy.to_json_value );
            END LOOP;
            
            person.put('policies', policies);
         END LOOP;
         
         ret_val.append( person.to_json_value );
      END LOOP;
      
      ret_val.print ;
   END generate_json;
END mongo_load_pkg;
/