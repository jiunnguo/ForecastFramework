require(dplyr)
ObservationList<- R6Class(
  classname= "ObservationList",
  inherit = AbstractObservationList,
  private = list(
    .aggregate = NULL,
    #' @importFrom dplyr data_frame
    .frame = data_frame(),
    aCurrent = FALSE,
    .aDims = list(),
    .aVal = '',
    .slice = 1,
    .aDimData = list(),
    na.rm = FALSE,
    updateArray = function(na.rm = private$na.rm){
      ##This function is for making sure private$.mat has the correct values.
      ##It should get called if aCurrent=FALSE any time self$mat is referenced
      if('updateArray' %in% private$.debug){
        browser()
      }
      ##as part of something, include optional arguments which do something
      ##  like this:
      ##colNames = self$frame %>%
      ##
      ##years %>%
      ##  full_join(biweeks) %>%
      ##  full_join(a$frame) %>%

      ##Check to make sure the matrix has been formed
      if(length(self$aDims) == 0){
        warning("Form array with formArray first")
        private$.arr = array(as.numeric(NA),c(0,0))
        private$.ndim = 2
        private$.dims = c(0,0)
        private$.dimData = list(list(),list())
        private$.dnames = list()
        return()
      }
      ##Deal with the case where private$.frame is empty
      if(nrow(private$.frame) == 0){
        ## Not sure if I should warn here.
        warning("The frame is empty.")
        private$.arr = array(as.numeric(NA),c(1:self$aDims*0))
        private$.ndim = length(self$aDims)
        private$.dims = 1:length(self$aDims)*0
        private$.dimData = lapply(self$aDims,list())
        private$.dnames = list()
        return()
      }
      private$.dnames = lapply(self$aDims,function(name){
        as.character(unique(private$.frame[[name]]))
      })
      private$.dims = sapply(private$.dnames,length)
      private$.ndim = length(private$.dims)
      #' @importFrom magrittr %>%
      private$.arr <- private$.frame %>%
        #' @importFrom dplyr select_
        select_(
          .dots = setNames(
            c(unlist(self$aDims),self$aVal),
            nm=c(unlist(self$aDims),self$aVal)
          )
        ) %>%
        #' @importFrom dplyr mutate_
        #' @importFrom dplyr group_by_
        group_by_(.dots=setNames(self$aDims,NULL)) %>%
        self$aggregate() %>%
        #' @importFrom dplyr ungroup
        ungroup() %>%
        #' @importFrom reshape2 acast
        acast(as.formula(paste(self$aDims,collapse='~')),value.var=self$aVal)
      mode(private$.arr) = 'numeric'
      ##}
      ##Get dimData from the matrix.  This relies on the aggregate function to
      ##  put everything in the right order
      ##Add a test case to make sure this puts everything in the right place.
      private$.dnames = dimnames(private$.arr)
      if(class(self$aDimData) == 'list'){
        if(length(self$aDimData) < length(self$aDims)){
          self$aDimData[length(self$aDims)] = list(NULL)
        }
      } else {
        stop("array metadata should be a list of columns in the data frame.")
      }
      private$.dimData = mapply(dim=self$aDims,data=self$aDimData,function(dim,data){
        self$frame %>%
          group_by_(dim) %>%
          self$aggregate() %>%
          ungroup() %>%
          select_(.dots=data) %>%
          as.list()
      })
      if(length(private$.dimData) < private$.ndim){
        private$.dimData = lapply(1:private$.ndim,function(x){
          if(length(private$.dimData >= x)){
            private$.dimData[[x]]
          } else {
            list()
          }
        })
      }
      private$aCurrent <- TRUE
    }
  ),
  public = list(
    initialize = function(data=data_frame(),...){
      self$frame <- as_data_frame(data)
      self$formArray(...)
      ## Note: We need to define aggregate here (instead of in the public list),
      ##   because things defined in lists are locked, and we want users to be
      ##   able to modify the .aggregate function
      private$.aggregate = function(input_data){
        if('aggregate' %in% private$.debug){
          browser()
        }
        #' @importFrom dplyr groups
        grouping = groups(input_data)
        input_data %>%
          #' @importFrom dplyr summarize_all
          #' @importFrom dplyr funs
          input_data <- summarize_all(funs(
            sum = if(is.numeric(.) || is.logical(.)){
              sum(.,na.rm=private$na.rm)
            } else{NA},
            unique = if(length(unique(.))==1){unique(.)} else{list(unique(.))}))
        input_data <- input_data %>%
          group_by_(.dots=grouping)
        if('sum' %in% names(input_data)){
          input_data <- input_data %>%
            #' @importFrom dplyr rename_
            rename_(.dots=setNames('sum',paste(private$.aVal,'_sum',sep='')))
        }
        if('unique' %in% names(input_data)){
          input_data <- input_data %>%
            rename_(
              .dots=setNames('unique',paste(private$.aVal,'_unique',sep=''))
            )
        }
        column_names = c(
          unlist(
            sapply(private$.aDimData,function(x){paste(x,"_unique",sep='')})
          ),
          paste(private$.aVal,'_sum',sep=''))
        column_names = column_names[column_names %in% names(input_data)]
        input_data %>%
          select_(.dots=column_names) ->
          input_data
        input_data %>%
          rename_(.dots=setNames(
            names(input_data)[grepl(names(input_data),pattern='_unique')],
            lapply(
              names(input_data)[grepl(names(input_data),pattern='_unique')],
              function(x){substr(x,1,nchar(x)-7)}
            )
          )) %>%
          rename_(.dots=setNames(
            names(input_data)[grepl(names(input_data),pattern='_sum')],
            lapply(
              names(input_data)[grepl(names(input_data),pattern='_sum')],
              function(x){substr(x,1,nchar(x)-4)}
            )
          )) %>%
          return()
      }
    },
    formArray = function(...,val,dimData=list(),metaData=list()){
      if('formArray' %in% private$.debug){
        browser()
      }
      if(missing(val)){
        if(length(list(...))==0){
          return()
        } else{
          stop("val must be supplied in order to form the incidenceArray")
        }
      }
      private$aCurrent=FALSE
      private$.dnames = NULL
      self$aDims = list(...)
      self$aVal = val
      self$aDimData = dimData
      ## This next line should be fixed at some point.  All of the other fields
      ##   reset on a new formArray call, but this one doesn't.
      metaDataKeys <-
        names(private$.metaData)[!(names(private$.metaData) %in% names(metaData))]
      ## Also I'm dubious that this works...  Probably need additional test
      ##   cases to check for it.
      self$metaData = c(private$.metaData[metaDataKeys],metaData)
    }
  ),
  active = list(
    #' @field frame The data frame this object is responsible for.
    frame = function(value){
      if('frame' %in% private$.debug){
        browser()
      }
      private$aCurrent = FALSE
      if(!missing(value)){
        private$.rnames = NULL
        private$.cnames = NULL
      }
      private$defaultActive('.frame','private',value)
    },
    arr = function(value){
      if('arr' %in% private$.debug){
       browser()
      }
      if(missing(value)){
        if(private$aCurrent == FALSE){
          private$updateArray()
        }
        #Fix Me
        return(private$.arr)
      }
      #super$arr <- value
      stop("Do not write directly to the array.")
    },
    #' @field dims The dimensions of \code{arr}
    dims = function(value){
      if('dims' %in% private$.debug){
       browser()
      }
      if(missing(value)){
        if(private$aCurrent == FALSE){
          private$updateArray()
        }
        return(private$.dims)
      }
      #super$dims <- value
      stop("Do not write directly to the dimensions.")
    },
    #' @field ndim The number of dimensions of \code{arr}
    ndim = function(value){
      if('ndim' %in% private$.debug){
       browser()
      }
      if(missing(value)){
        if(private$aCurrent == FALSE){
          private$updateArray()
        }
        return(private$.ndim)
      }
      #super$ndim <- value
      stop("Do not write directly to the number of dimensions.")
    },
    #' @field dimData A list of data associated with each dimension of \code{arr}
    dimData = function(value){
      if('dimData' %in% private$.debug){
       browser()
      }
      if(private$aCurrent == FALSE){
        private$updateArray()
      }
      if(missing(value)){
        return(private$.dimData)
      }
      if(is.null(value)){
        private$.dimData=NULL
      } else if(class(value) == 'list'){
        nval = length(value)
        if(nval == 0){
          private$.dimData = value
        } else if(nval <= private$.ndim){
          if(all(mapply(function(self,other){
            is.null(other) ||
            all(sapply(other,function(x){self==length(x)}))
          },
          self = private$.dims[1:nval],
          other=value
          ))){
            private$.dimData[!sapply(value,is.null)] = value[!sapply(value,is.null)]
          } else {
            stop("The dimensions don't match up.")
          }
        } else {
          stop("Invalid number of dimensions.")
        }
      } else {
        stop(paste(
          "Not sure how to make dimension metaData from object of class",
          class(value)
        ))
      }
    },
    #' @field dnames The names of the slices of each dimension of \code{self$arr}
    dnames = function(value){
      if('dnames' %in% private$.debug){
       browser()
      }
      if(missing(value)){
        if(private$aCurrent == FALSE){
          private$updateArray()
        }
        return(private$.dnames)
      }
      #super$dnames <- value
      stop("Do not write directly to the dimension names.")
    },
    #' @field nrow The number of rows in \code{self$arr}
    nrow = function(value){
      if('nrow' %in% private$.debug){
       browser()
      }
      if(missing(value)){
        if(private$aCurrent == FALSE){
          private$updateArray()
        }
        return(private$.dims[1])
      }
      #super$nrow <- value
      stop("Do not write directly to the number of rows.")
    },
    #' @field ncol The number of columns in \code{self$arr}
    ncol = function(value){
      if('ncol' %in% private$.debug){
       browser()
      }
      if(missing(value)){
        if(private$aCurrent == FALSE){
          private$updateArray()
        }
        return(private$.dims[2])
      }
      #super$ncol <- value
      stop("Do not write directly to the number of columns.")
    },
    #' @field rnames The names of the rows of \code{self$arr}
    rnames = function(value){
      if('rnames' %in% private$.debug){
       browser()
      }
      if(missing(value)){
        if(private$aCurrent == FALSE){
          private$updateArray()
        }
        return(private$.dnames[[1]])
      }
      #super$rnames <- value
      stop("Do not write directly to the row names.")
    },
    #' @field cnames The names of the rows of \code{self$arr}
    cnames = function(value){
      if('cnames' %in% private$.debug){
       browser()
      }
      if(missing(value)){
        if(private$aCurrent == FALSE){
          private$updateArray()
        }
        return(private$.dnames[[2]])
      }
      #super$cnames <- value
      stop("Do not write directly to the column names.")
    },
    #' @field colData A list of data associated to the columns of \code{self$arr}
    colData = function(value){
      if('colData' %in% private$.debug){
       browser()
      }
      if(missing(value)){
        if(private$aCurrent == FALSE){
          private$updateArray()
        }
        return(self$dimData[[2]])
      }
      #super$colData <- value
      self$dimData[[2]] <- value
    },
    #' @field rowData A list of data associated to the rows of \code{self$arr}
    rowData = function(value){
      if('rowData' %in% private$.debug){
       browser()
      }
      if(missing(value)){
        if(private$aCurrent == FALSE){
          private$updateArray()
        }
        return(self$dimData[[1]])
      }
      #super$rowData <- value
      self$dimData[[1]] <- value
    },
    aDims = function(value){
      if('aDims' %in% private$.debug){
        browser()
      }
      if(missing(value)){
        return(private$.aDims)
      }
      lapply(value,function(value){
        if(!all(value %in% colnames(private$.frame))){
          stop(paste(value,"is not a column of the frame"))
        }
      })
      private$.aDims = value
      private$aCurrent = FALSE
    },
    aVal = function(value){
      if('aVal' %in% private$.debug){
        browser()
      }
      if(missing(value)){
        return(private$.aVal)
      }
      if(!(value %in% colnames(private$.frame))){
        stop(paste(value,"is not a column of the frame"))
      }
      private$.aVal = value
      private$aCurrent = FALSE
    },
    aDimData = function(value){
      if('aDimData' %in% private$.debug){
        browser()
      }
      if(missing(value)){
        return(private$.aDimData)
      }
      lapply(value,function(value){
        for(val in value){
          if(!(val %in% colnames(private$.frame))){
            stop(paste(val,"is not a column of the frame"))
          }
        }
      })
      private$.aDimData = value
      private$aCurrent = FALSE
    },
    #' @field mat A matrix pulled from a cross section of \code{self$arr}
    mat = function(value){
      if('mat' %in% private$.debug){
        browser()
      }
      if(missing(value)){
        if(private$aCurrent == FALSE){
          private$updateArray()
        }
        if(private$.ndim == 2){
          return(as.matrix(private$.arr))
        }
        return(apply(private$.arr,c(1,2),function(x){x[slice]}))
      }
      stop(paste(
        "Do not write directly to the mat, because it is automatically",
        "calculated.  The Observation List is called frame"
      ))
    },
    slice = function(value){
      if(missing(value)){
        return(private$.slice)
      }
      if(any(c(1,1,value) > self$dims)){
        stop("Value must be between 1 and length in that dimension.")
      }
      private$.slice = matrix(value,1)
    },
    aggregate = function(value){
      if(missing(value)){
        return(private$.aggregate)
      }
      private$aCurrent = FALSE
      if(class(value) != 'function'){
        stop(paste(
          "Not a function.  aggregate should be a function taking a single",
          "data_frame argument called input_data"
        ))
      }
      if(length(names(formals(fun=value))) != 1){
        stop(paste(
          "Not a valid function for aggregation.  A valid aggregation function",
          "must take a single data_frame argument."
        ))
      }
      private$.aggregate = value
    }
  )
)
