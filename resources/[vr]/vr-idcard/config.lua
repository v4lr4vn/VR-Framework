return {

   mugshotsUpload = 'database',

   settings = {
      closeControl = 177,
      autoClose = {
         status = true,
         time = 8000
      },
      mugshotScale = 0.88
   },

   licenses = {
      ['id_card'] = {
         header = 'Identity Card',
         background = '#ebf7fd',
         prop = `prop_franklin_dl`
      },
      ['driver_license'] = {
         header = 'Driver License',
         background = '#febbbb',
         prop = `prop_franklin_dl`,
      },
      ['weaponlicense'] = {
         header = 'Weapon License',
         background = '#c7ffe5',
         prop = `prop_franklin_dl`,
      },
      ['lawyerpass'] = {
         header = 'Lawyer Pass',
         background = '#f9c491',
         prop = `prop_cs_r_business_card`
      },
   }

}
