
# paquetes ----------------------------------------------------------------
pacman::p_load(
    tidyverse, xts, broom, forecast, 
    lmtest, data.table, knitr, tsr,
    ggplot2, formula.tools
  )

# carpetas de trabajo -----------------------------------------------------

carpeta_datos <- here::here("data")
carpeta_resultados <- here::here("6-models")

# datos -------------------------------------------------------------------

load(file.path(carpeta_datos, "vars.RData"))
load(file.path(carpeta_datos, "exogeneidad.RData"))

l_vars <- log(vars)
n_l_vars <- names(l_vars)
n_l_vars[str_detect(n_l_vars, "tiie_28")] <- "tiie"

names(l_vars) <- n_l_vars


# Modelos -----------------------------------------------------------------

dep_vars <- 
  c(
    "monto_spei",
    "monto_tpv_deb",
    "monto_tpv_cred",
    "monto_cheques"
  )


models <- 
  dep_vars %>% 
  map(
    function(var){
      c(
        str_glue("{var}~inpc+delictivo+tiie+busqueda"), 
        str_glue("{var}~inpc+delictivo+tiie+busqueda+pib")
      )
    }
  ) %>% 
  reduce(c)

names_dyn_models <- c("mdg", "mdgd", "mce")


models %>% 
  walk(
    function(model){
      #CREATING FOLDERS
      model_carpeta <- file.path(carpeta_resultados, model)
      
      if(!dir.exists(model_carpeta)){
        dir.create(model_carpeta)
      }
      
      #CREATEING TXT
      text_results <- file.path(model_carpeta, "resultados.txt")
      
      if(file.exists(text_results)){
        file.remove(text_results)
      }
      
      file.create(text_results)
      
      cat("Modelo:", model, file = text_results, append = T)
      
      # THREE MODELS
      # ADJUSTING MODELS
      dyn_models <- 
        names_dyn_models %>% 
        map(
          ~dynamic_model(
            model, 
            l_vars, 
            order = c(4, 4, 4), 
            type_model = .
          )
        ) %>% 
        set_names(names_dyn_models)
      
      # REPORTING RESULTS OF MODELS
      names_dyn_models %>% 
        walk(
          function(dyn_model){
            # MODEL WE ARE ANALYSING
            especific_model <- dyn_models[[dyn_model]]
            
            # TITLE
            cat("\n", dyn_model, ":", "\n", file = text_results,  append = T)
            cat("\n", file = text_results,  append = T)
            
            # SIGNIFICANCE
            table_sign <- tidy(coeftest(especific_model))
            
            cat(kable(table_sign, "latex"), file = text_results, append = T)
            cat("\n", file = text_results,  append = T)
            
            # PLOT OF RESIDUALS
            file_plot_residuals <- 
              file.path(
                model_carpeta, 
                str_glue("residuals-{dyn_model}.png")
              )
            png(filename = file_plot_residuals, width = 900, height = 0.68*900)
            print(
              checkresiduals(especific_model)
            )
            dev.off()    
            
            # PLOT OF RESIDUALS
            file_plot_multipliers <- 
              file.path(
                model_carpeta, 
                str_glue("multipliers-{dyn_model}.png")
              )
            png(filename = file_plot_multipliers, width = 900, height = 0.68*900)
            print(
              dynamic_mult(especific_model) + 
                labs(
                  title = str_glue("Dynamic multipliers {dyn_model}"),
                  subtitle = str_glue("{model}")
                ) 
            )
            dev.off()    
            
          }
        )
      
      # COMPARISON OF MODELS
      comparison <- compare_dyn_models(dyn_models)
      cat("\n", "Comparación de modelos:", "\n", file = text_results, append = T)
      
      # matrix comparison
      cat(
        kable(
          comparison, 
          "latex",
          row.names = c(NA, rownames(comparison)),
          col.names = colnames(comparison)
        ), 
        file = text_results,
        append = T
      )
      
      cat("\n", "Resultados:", "\n", file = text_results, append = T)
      resultados <- attr(comparison, "results")
      cat(
        kable(matrix(resultados, 1, 3), "latex"),
        file = text_results,
        append = T
      )
    }
  )

beepr::beep(2)



