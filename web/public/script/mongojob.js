$(function(){

  // Attach actions to specific buttons
  // Job
  $('.job .actions .kill').live('click', function(){
    var id = $(this).closest('.job').attr('data-id');
    $.ajax({
      dataType: 'json',
      url: '/job/' + id,
      type: 'DELETE',
      complete: function(){window.location.reload();}
    });
  });
  
});