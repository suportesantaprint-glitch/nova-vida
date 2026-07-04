const app = {
  open: () => {
    $("#mainElevador").fadeIn(500);
  },
  close: () => {
    $("#mainElevador").fadeOut(500);
    $.post(`https://${GetParentResourceName()}/close`);
  },
};

let visual = null

window.addEventListener("message", function (event) {

  if (event.data.action == "OPEN_NUI") {

    $("#mainElevador menu section").html("");

    if (event.data.name != undefined) {
      $(".elevadorName").html(event.data.name);
    } else {
      $(".elevadorName").html("ELEVATOR");
    }

    if (event.data.text != undefined) {
      $(".elevadorText").html(event.data.text);
    } else {
      $(".elevadorText").html("Available Floors");
    }

    visual = event.data.visual

    if (visual != undefined) {
      $(".elevadorName").css('color',visual.name_color ? visual.name_color : '#d40000')
      $(".elevadorText").css('color',visual.text_color ? visual.text_color : '#d40000')
    }

    const id = event.data.id;
    const locs = event.data.floors;

    locs.map((v,k)=>{
      let fid = k+1
      let fname = `Floor ${k}`
      if(v.text){ fname = v.text; };

      $("#mainElevador menu section").append(`
        <div class="item" onCLick="elevadorMove(${id},${fid})">
          <span>${fname}</span>
        </div>
      `);
    })

    app.open();
    $("#mainElevador").css("display", "flex");
  }

  $(".item").hover(function(e) {
    if (visual != undefined) {
      const color = visual.floors_color ? visual.floors_color : '#d40000'
      $(this).css("background-color", e.type === "mouseenter" ? color : "rgba(0,0,0,0.5)" )
    }
  })

  document.onkeyup = function (data) {
    if (data.which == 27) {
      app.close();
    }
  };

});



function elevadorMove(i,f) {
  $.post(`https://${GetParentResourceName()}/elevatorFloor`, JSON.stringify({ id: i, select: f }));
  app.close();
}